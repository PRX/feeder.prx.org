module Megaphone
  class Episode < Integrations::Base::Episode
    include Megaphone::Model
    attr_accessor :podcast

    # track upload source data
    SOURCE_ATTRIBUTES = [:source_media_version_id, :source_size, :source_fetch_count, :source_url, :source_filename]
    attr_accessor(*SOURCE_ATTRIBUTES)

    # Used to form the adhash value
    ADHASH_VALUES = {"pre" => "0", "mid" => "1", "post" => "2"}.freeze

    # Required attributes for a create
    # external_id is not required by megaphone, but we need it to be set!
    CREATE_REQUIRED = %i[title external_id]

    CREATE_ATTRIBUTES = CREATE_REQUIRED + %i[pubdate pubdate_timezone author link explicit draft
      subtitle summary background_image_file_url background_audio_file_url pre_count post_count
      insertion_points guid pre_offset post_offset expected_adhash original_filename original_url
      episode_number season_number retain_ad_locations advertising_tags ad_free]

    UPDATE_ATTRIBUTES = CREATE_ATTRIBUTES

    # All other attributes we might expect back from the Megaphone API
    # (some documented, others not so much)
    OTHER_ATTRIBUTES = %i[id podcast_id created_at updated_at status
      download_url audio_file_processing audio_file_status audio_file_updated_at]

    DEPRECATED = %i[]

    ALL_ATTRIBUTES = (CREATE_ATTRIBUTES + DEPRECATED + OTHER_ATTRIBUTES)

    attr_accessor(*ALL_ATTRIBUTES)

    validates_presence_of CREATE_REQUIRED

    validates_presence_of :id, on: :update

    validates_absence_of :id, on: :create

    def self.find_by_episode(megaphone_podcast, feeder_episode)
      episode = new_from_episode(megaphone_podcast, feeder_episode)
      sync_log = feeder_episode.sync_log(:megaphone)
      mp = episode.find_by_megaphone_id(sync_log&.external_id)
      mp ||= episode.find_by_guid(feeder_episode.guid)
      mp
    end

    def self.new_from_episode(megaphone_podcast, feeder_episode)
      # start with basic attributes copied from the feeder episode
      episode = Megaphone::Episode.new(attributes_from_episode(feeder_episode))

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

    def self.attributes_from_episode(e)
      {
        title: e.title,
        external_id: e.guid,
        guid: e.item_guid,
        pubdate: e.published_or_released_date,
        pubdate_timezone: e.published_or_released_date&.time_zone&.name,
        author: e.author_name,
        link: e.url,
        explicit: e.explicit,
        draft: e.draft?,
        subtitle: e.subtitle,
        summary: e.description,
        background_image_file_url: e.ready_image&.href,
        episode_number: e.episode_number,
        season_number: e.season_number,
        advertising_tags: e.categories,
        ad_free: e.categories.include?("adfree")
      }
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
    end

    def update!(episode = nil)
      if episode
        self.attributes = self.class.attributes_from_episode(episode)
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
    end

    # call this when we need to update the audio on mp
    # like when dtr wasn't ready at first
    # so we can make that update and then mark uploaded
    def upload_audio!
      set_audio_attributes
      update!
    end

    # call this when audio has been updated on mp
    # and we're checking to see if mp is done processing
    # so we can update cuepoints and mark delivered
    def check_audio!
      # Re-request the megaphone api
      find_by_megaphone_id

      # get the audio attributes from feeder
      set_audio_attributes

      # check to see if the audio on mp matches
      if original_filename == source_filename
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

    def set_enclosure
      return unless audio_file_status == "success"
      return if no_audio download_url.blank? || feeder_episode.enclosure_override_url.present?
      feeder_episode.update(enclosure_override_url: download_url, enclosure_override_prefix: true)
    end

    def replace_cuepoints!
      # retrieve the placement info from augury
      zones = get_placement_zones(feeder_episode.segment_count)
      media = feeder_episode.media

      # create cuepoint instances from that
      cuepoints = Megaphone::Cuepoint.from_zones_and_media(zones, media)

      # put those as a list to the mp api
      cuepoints_batch!(cuepoints)
    end

    def cuepoints_batch!(cuepoints)
      # validate all the cuepoints about to be created
      cuepoints.all? { |cp| cp.validate!(:create) }
      body = cuepoints.map { |cp| cp.as_json_for_create }
      self.api_response = api.put("podcasts/#{podcast.id}/episodes/#{id}/cuepoints_batch", body)
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
      # if there's audio and we just uploaded it successfully, set attr, then check status
      if feeder_episode.complete_media? && background_audio_file_url
        attrs = source_attributes.merge(uploaded: true)
        feeder_episode.update_episode_delivery_status(:megaphone, attrs)
      # or if there's not audio yet or it didn't change
      else
        # we're done, mark it as delivered!
        delivery_status(true).mark_as_delivered!
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
      if original_count.to_i < 1
        original_count = (feeder_episode&.segment_count || 1).to_i
      end
      placements = Prx::Augury.new.placements(feeder_podcast.id)
      placement = placements&.find { |i| i.original_count == original_count }
      (placement&.zones || []).map(&:with_indifferent_access)
    end

    # call this before create or update, yah
    def set_audio_attributes
      return unless feeder_episode.complete_media?

      # check if the version is different from what was saved before
      if !has_media_version?
        media_info = get_media_info(enclosure_url)

        # if dovetail has the right media info, we can update
        if media_info[:media_version] == feeder_episode.media_version_id
          self.source_media_version_id = media_info[:media_version]
          self.source_size = media_info[:size]
          self.source_fetch_count = (delivery_status&.source_fetch_count || 0) + 1
          self.source_url = arrangement_version_url(media_info[:location], media_info[:media_version], source_fetch_count)
          self.source_filename = url_filename(source_url)
          self.background_audio_file_url = source_url
          self.insertion_points = timings
          self.retain_ad_locations = true
        else
          # if not, mark it as not uploaded and move on
          delivery_status.mark_as_not_uploaded!
        end
      end
    end

    def source_attributes
      attributes.slice(*SOURCE_ATTRIBUTES)
    end

    def get_media_info(enclosure)
      info = {
        enclosure_url: enclosure,
        media_version: nil,
        location: nil,
        size: nil
      }
      resp = Faraday.head(enclosure)
      if resp.status == 302
        info[:media_version] = resp.env.response_headers["x-episode-media-version"]
        info[:location] = resp.env.response_headers["location"]
        info[:size] = resp.env.response_headers["content-length"]
      else
        logger.error("DTR media redirect not returned: #{resp.status}", enclosure: enclosure, resp: resp)
        raise("DTR media redirect not returned: #{resp.status}")
      end
      info
    rescue => err
      logger.error("Error getting DTR media info", enclosure: enclosure, error: err)
      raise err
    end

    def arrangement_version_url(location, media_version, count)
      uri = URI.parse(location)
      path = uri.path.split("/")
      ext = File.extname(path.last)
      base = File.basename(path.last, ext)
      filename = "#{base}_#{media_version}_#{count}#{ext}"
      uri.path = (path[0..-2] + [filename]).join("/")
    end

    def url_filename(url)
      URI.parse(url).path.split("/").last
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
  end
end
