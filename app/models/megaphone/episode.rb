module Megaphone
  class Episode < Integrations::Base::Episode
    include Megaphone::Model
    attr_accessor :podcast

    # track upload source data
    SOURCE_ATTRIBUTES = %i[source_media_version_id source_size source_fetch_count source_url source_filename]
    attr_accessor(*SOURCE_ATTRIBUTES)

    # Used to form the adhash value
    ADHASH_VALUES = {"pre" => "0", "mid" => "1", "post" => "2"}.freeze

    # Required attributes for a create
    # external_id is not required by megaphone, but we need it to be set!
    CREATE_REQUIRED = %i[title external_id]

    CREATE_ATTRIBUTES = CREATE_REQUIRED + %i[pubdate pubdate_timezone author link explicit draft
      subtitle summary background_image_file_url background_audio_file_url pre_count post_count
      insertion_points guid expected_adhash original_filename episode_number season_number
      retain_ad_locations ad_free episode_type clean_title]

    UPDATE_ATTRIBUTES = CREATE_ATTRIBUTES

    # All other attributes we might expect back from the Megaphone API
    # (some documented, others not so much)
    OTHER_ATTRIBUTES = %i[id podcast_id created_at updated_at status download_url parent_id
      audio_file_processing audio_file_status audio_file_updated_at pre_offset post_offset
      image_file audio_file size duration uid original_url bitrate samplerate channel_mode vbr
      id3_file id3_file_processing id3_file_size spotify_identifier custom_fields content_rating
      promotional_content podcast_title network_id podcast_author podcast_itunes_categories
      episode_video_thumbnail_url main_feed rss_status spotify_status cuepoints advertising_tags]

    DEPRECATED = %i[]

    ALL_ATTRIBUTES = (CREATE_ATTRIBUTES + DEPRECATED + OTHER_ATTRIBUTES)

    attr_accessor(*ALL_ATTRIBUTES)

    validates_presence_of CREATE_REQUIRED

    validates_presence_of :id, on: :update

    validates_absence_of :id, on: :create

    def self.list(megaphone_podcast)
      episode = Megaphone::Episode.new
      episode.podcast = megaphone_podcast
      episode.config = megaphone_podcast.config
      episode.list
    end

    def self.find_by_episode(megaphone_podcast, feeder_episode)
      episode = new_from_episode(megaphone_podcast, feeder_episode)
      sync_log = feeder_episode.sync_log(:megaphone)
      mp = episode.find_by_megaphone_id(sync_log&.external_id)
      mp ||= episode.find_by_guid(feeder_episode.guid)
      mp
    end

    def self.new_from_episode(megaphone_podcast, feeder_episode)
      # start with basic attributes copied from the feeder episode
      episode = Megaphone::Episode.new(attributes_from_episode(feeder_episode, megaphone_podcast.private_feed))

      # set relations to the feeder episode and megaphone podcast
      episode.feeder_episode = feeder_episode
      episode.podcast = megaphone_podcast
      episode.config = megaphone_podcast.config

      # we should always be able to set these, published or not
      # this does make a remote call to get the placements from augury
      episode.set_placement_attributes

      # may move this later, but let's also see about audio
      episode.set_audio_attributes

      episode
    end

    def self.attributes_from_episode(e, feed)
      pubdate = if e.published_or_released_date
        e.published_or_released_date + feed.episode_offset_seconds.to_i.seconds
      end

      {
        title: e.title,
        external_id: e.guid,
        guid: e.item_guid,
        parent_id: e.original_guid,
        pubdate: pubdate,
        pubdate_timezone: pubdate&.time_zone&.name,
        author: e.author_name,
        link: e.url,
        explicit: e.explicit,
        draft: e.draft?,
        clean_title: e.clean_title,
        subtitle: e.subtitle,
        summary: e.description,
        background_image_file_url: e.ready_image&.href,
        episode_type: e.itunes_type,
        episode_number: e.episode_number,
        season_number: e.season_number,
        ad_free: e.categories.include?("adfree")
      }
    end

    def initialize(attributes = {})
      super(attributes.slice(*ALL_ATTRIBUTES))
    end

    def to_h
      as_json.with_indifferent_access.slice(*ALL_ATTRIBUTES)
    end

    def list
      self.api_response = api.get("podcasts/#{podcast.id}/episodes")
      Megaphone::PagedCollection.new(api, Megaphone::Episode, api_response).all_items
    end

    def find_by_guid(guid = feeder_episode.guid)
      return nil if guid.blank?
      self.api_response = api.get("podcasts/#{podcast.id}/episodes", externalId: guid)
      handle_response(api_response)
    end

    def find_by_megaphone_id(mpid = id)
      return nil if mpid.blank?
      self.api_response = api.get("podcasts/#{podcast.id}/episodes/#{mpid}")
      handle_response(api_response)
    end

    def create!
      validate!(:create)
      body = as_json(only: CREATE_ATTRIBUTES.map(&:to_s))
      self.api_response = api.post("podcasts/#{podcast.id}/episodes", body)
      handle_response(api_response)
      update_sync_log
      update_delivery_status
      set_enclosure
      self
    rescue Faraday::ClientError => ce
      self.api_response = ce.response
      raise ce
    rescue => e
      logger.error("Error creating episode in Megaphone", error: e)
      raise e
    end

    def update!(episode = nil)
      if episode
        self.attributes = self.class.attributes_from_episode(episode, private_feed)
        set_placement_attributes
        set_audio_attributes
      end
      validate!(:update)
      body = as_json(only: UPDATE_ATTRIBUTES.map(&:to_s))
      self.api_response = api.put("podcasts/#{podcast.id}/episodes/#{id}", body)
      handle_response(api_response)
      update_sync_log
      update_delivery_status
      set_enclosure
      self
    rescue Faraday::ClientError => ce
      self.api_response = ce.response
      raise ce
    rescue => e
      logger.error("Error updating episode in Megaphone", error: e)
      raise e
    end

    def delete!
      self.api_response = api.delete("podcasts/#{podcast.id}/episodes/#{id}")
      delete_sync_log
      delete_delivery_status
      self
    rescue Faraday::ClientError => ce
      self.api_response = ce.response
      raise ce
    rescue => e
      logger.error("Error deleting episode in Megaphone", error: e)
      raise e
    end

    def delete_sync_log
      sync_log = feeder_episode.sync_log(:megaphone)
      sync_log.destroy!
    end

    def delete_delivery_status
      feeder_episode.delete_episode_delivery_status(:megaphone)
    end

    # call this when we need to update the audio on mp
    # like when dtr wasn't ready at first
    # so we can make that update and then mark uploaded
    def upload_audio!
      # basically just do an update, passing in the episode
      # which will override the audio attributes
      update!(feeder_episode)
    end

    # call this when audio has been updated on mp
    # and we're checking to see if mp is done processing
    # so we can update cuepoints and mark delivered
    def check_audio!
      # Re-request the megaphone api
      find_by_megaphone_id

      # check to see if the audio on mp matches latest delivery
      if original_filename == delivery_status(true).source_filename
        # if processing done, set the cuepoints and the enclosure
        if !audio_file_processing && audio_file_status == "success"
          set_enclosure
          replace_cuepoints!
          delivery_status(true).mark_as_delivered!
        else
          # still waiting - increment asset state
          delivery_status(true).increment_asset_wait
        end
      else
        # this would be a weird timing thing maybe, but ...
        # if the files don't match, we need to go back and upload
        delivery_status(true).mark_as_not_uploaded!
      end
    end

    def audio_is_latest?
      feeder_audio_updated_at = feeder_episode.media_versions.last&.updated_at
      megaphone_updated_at = DateTime.parse(audio_file_updated_at) if audio_file_updated_at
      megaphone_updated_at && feeder_audio_updated_at && feeder_audio_updated_at <= megaphone_updated_at
    end

    def set_enclosure
      return if download_url.blank? || !feeder_episode.complete_media?
      set_external_media
      feeder_episode.update!(enclosure_override_url: download_url, enclosure_override_prefix: true)
    end

    # if it's not published yet, can't get the file from mp, create as "complete"
    def set_external_media
      return if feeder_episode.published?

      emr_attributes = {
        status: :complete,
        mime_type: "audio/mpeg",
        medium: "audio",
        original_url: download_url,
        file_size: feeder_episode.media_file_size_sum,
        duration: feeder_episode.media_duration_sum,
        bit_rate: private_feed.audio_format[:b].to_i,
        channels: private_feed.audio_format[:c].to_i,
        sample_rate: private_feed.audio_format[:s].to_i
      }
      if feeder_episode.external_media_resource
        feeder_episode.external_media_resource.update!(emr_attributes)
      else
        feeder_episode.create_external_media_resource!(emr_attributes)
      end
    end

    def replace_cuepoints!
      # retrieve the placement info from augury
      placement = get_placement(feeder_episode.segment_count)
      media = feeder_episode.media

      # create cuepoint instances from that
      cuepoints = Megaphone::Cuepoint.from_placement_and_media(placement, media)

      # put those as a list to the mp api
      cuepoints_batch!(cuepoints)
    end

    def cuepoints_batch!(cuepoints)
      # validate all the cuepoints about to be created
      cuepoints.all? { |cp| cp.validate!(:create) }
      body = cuepoints.map { |cp| cp.as_json_for_create }
      self.api_response = api.put_base("episodes/#{id}/cuepoints_batch", body)
      update_sync_log
      update_delivery_status
      self
    end

    def update_sync_log
      SyncLog.log!(
        integration: :megaphone,
        feeder_id: feeder_episode.id,
        feeder_type: :episodes,
        external_id: id,
        api_response: api_response_log_item
      )
    end

    def handle_response(api_response)
      if (item = (api_response[:items] || []).first)
        self.attributes = item.slice(*ALL_ATTRIBUTES)
        self
      end
    end

    # update delivery status after a create or update
    def update_delivery_status
      # if there is not audio yet, we're all done
      if !feeder_episode.complete_media?
        delivery_status(true).mark_as_delivered!
      # if the audio doesn't match, either it was just uploaded, or needs it
      elsif !has_media_version?
        # if there's audio and we just uploaded it successfully, set attr, then check status
        if background_audio_file_url
          attrs = source_attributes.merge(
            enclosure_url: background_audio_file_url,
            uploaded: true,
            delivered: false
          )
          feeder_episode.update_episode_delivery_status(:megaphone, attrs)
        # if versions don't match, and we didn't upload, it isn't uploaded or delivered
        else
          delivery_status(true).mark_as_not_delivered!
        end
      else
        # media is complete and has the right version, that's uploaded!
        # next pass through check_audio! should mark it delivered if mp matches and is complete
        delivery_status(true).mark_as_uploaded!
      end
      feeder_episode.episode_delivery_statuses.reset
    end

    def private_feed
      podcast.private_feed
    end

    def synced_with_integration?
      delivery_status&.delivered?
    end

    def integration_new?
      false
    end

    def archived?
      false
    end

    def feeder_podcast
      feeder_episode.podcast
    end

    def delivery_status(with_default = false)
      feeder_episode&.episode_delivery_status(:megaphone, with_default)
    end

    def set_placement_attributes
      if (zones = get_placement_zones(feeder_episode.segment_count))
        self.expected_adhash = adhash_for_placement(zones)
        self.pre_count = expected_adhash.count("0")
        self.post_count = expected_adhash.count("2")
      end
    end

    def adhash_for_placement(zones)
      zones
        .filter { |z| ["ad", "sonic_id", "house"].include?(z[:type]) }
        .map { |z| ADHASH_VALUES[z[:section]] }
        .join("")
    end

    def get_placement_zones(original_count = nil)
      get_placement(original_count)&.zones || []
    end

    def get_placement(original_count = nil)
      if original_count.to_i < 1
        original_count = (feeder_episode&.segment_count || 1).to_i
      end
      placements = Prx::Augury.new.placements(feeder_podcast.id)
      placements&.find { |p| p.original_count == original_count }
    end

    # call this before create or update, yah
    def set_audio_attributes
      return unless feeder_episode.complete_media?

      # check if the version is different from what was uploaded before,
      # need to upload and deliver
      if !has_media_version?
        media_info = get_media_info(enclosure_url)

        # if dovetail has the right media info, we can update
        if media_info[:media_version] == feeder_episode.media_version_id
          audio_url = arrangement_version_url(media_info[:location], media_info[:media_version])
          audio_filename = url_filename(audio_url)

          self.source_media_version_id = media_info[:media_version]
          self.source_size = media_info[:size]
          self.source_fetch_count = (delivery_status&.source_fetch_count || 0) + 1
          self.source_url = audio_url
          self.source_filename = audio_filename

          self.background_audio_file_url = audio_url
          self.original_filename = audio_filename
          self.insertion_points = timings
          self.retain_ad_locations = true
        end
      end
    end

    def source_attributes
      SOURCE_ATTRIBUTES.map { |a| [a, send(a)] }.to_h
    end

    def get_media_info(enclosure)
      info = {
        enclosure_url: enclosure,
        media_version: nil,
        location: nil,
        size: nil
      }.with_indifferent_access
      resp = Faraday.head(enclosure)
      if resp.status == 302
        info[:media_version] = resp.env.response_headers["x-episode-media-version"].to_i
        info[:location] = resp.env.response_headers["location"]
        info[:size] = resp.env.response_headers["content-length"].to_i
      else
        logger.error("DTR media redirect not returned: #{resp&.status}", enclosure: enclosure, headers: resp&.env&.response_headers)
        raise("DTR media redirect not returned: #{resp&.status}")
      end
      info
    rescue => err
      logger.error("Error getting DTR media info", enclosure: enclosure, error: err)
      raise err
    end

    def arrangement_version_url(location, media_version)
      uri = URI.parse(location)
      path = uri.path.split("/")
      ext = File.extname(path.last)
      base = File.basename(path.last, ext)
      filename = "#{base}_#{media_version}#{ext}"
      uri.path = (path[0..-2] + [filename]).join("/")
      uri.to_s
    end

    def url_filename(url)
      URI.parse(url || "").path.split("/").last
    end

    def enclosure_url
      url = EnclosureUrlBuilder.new.base_enclosure_url(
        feeder_podcast,
        feeder_episode,
        private_feed
      )
      EnclosureUrlBuilder.mark_authorized(url, private_feed)
    end

    def timings
      feeder_episode.media[0..-2].map(&:duration)
    end

    def pre_after_original?(zones)
      sections = zones.split { |z| z[:type] == "original" }
      sections[1].any? { |z| %w[ad house].include?(z[:type]) && z[:id].match(/pre/) }
    end

    def post_before_original?(zones)
      sections = zones.split { |z| z[:type] == "original" }
      sections[-2].any? { |z| %w[ad house].include?(z[:type]) && z[:id].match(/post/) }
    end

    def item_guid
      guid || parent_id || id
    end
  end
end
