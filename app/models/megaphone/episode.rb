module Megaphone
  class Episode < Integrations::Base::Episode
    include Megaphone::Model
    attr_accessor :private_feed

    # Used to form the adhash value
    ADHASH_VALUES = {"pre" => "0", "mid" => "1", "post" => "2"}.freeze

    # Required attributes for a create
    # external_id is not required by megaphone, but we need it to be set!
    CREATE_REQUIRED = %i[title external_id]

    CREATE_ATTRIBUTES = CREATE_REQUIRED + %i[pubdate pubdate_timezone author link explicit draft
      subtitle summary background_image_file_url background_audio_file_url pre_count post_count
      insertion_points guid pre_offset post_offset expected_adhash original_filename original_url
      episode_number season_number retain_ad_locations advertising_tags ad_free]

    # All other attributes we might expect back from the Megaphone API
    # (some documented, others not so much)
    OTHER_ATTRIBUTES = %i[id created_at updated_at]

    DEPRECATED = %i[]

    ALL_ATTRIBUTES = (CREATE_ATTRIBUTES + DEPRECATED + OTHER_ATTRIBUTES)

    attr_accessor(*ALL_ATTRIBUTES)

    validates_presence_of CREATE_REQUIRED

    validates_presence_of :id, on: :update

    validates_absence_of :id, on: :create

    def self.new_from_episode(feed, feeder_episode)
      episode = Megaphone::Episode.new(attributes_from_episode(feeder_episode))
      episode.feeder_episode = feeder_episode
      episode.private_feed = feed
      episode.config = feed.config
      episode
    end

    def self.attributes_from_episode(e)
      {
        title: e.title,
        external_id: e.guid,
        guid: e.item_guid,
        pubdate: e.published_at,
        pubdate_timezone: e.published_at.zone,
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

    def synced_with_integration?
      delivery_status&.delivered?
    end

    def integration_new?
      false
    end

    def archived?
      false
    end

    def delivery_status
      feeder_episode&.episode_delivery_status(:megaphone)
    end

    def set_placement_attributes
      placement = get_placement(feeder_episode.segment_count)
      self.expected_adhash = adhash_for_placement(placement)
      self.pre_count = expected_adhash.count("0")
      self.post_count = expected_adhash.count("2")
    end

    def adhash_for_placement(placement)
      placement
        .zones
        .filter { |z| z["type"] == "ad" }
        .map { |z| ADHASH_VALUES[z["section"]] }
        .join("")
    end

    def get_placement(original_count)
      placements = Prx::Augury.new.placements(@podcast.id)
      placements&.find { |i| i.original_count == original_count }
    end

    # call this before create or update, yah
    def set_audio_attributes
      return unless feeder_episode.complete_media?
      self.background_audio_file_url = upload_url
      self.insertion_points = timings
      self.retain_ad_locations = true
    end

    def upload_url
      resp = Faraday.head(enclosure_url)
      if resp.status == 302
        media_version = resp.env.response_headers["x-episode-media-version"]
        if media_version == feeder_episode.media_version_id
          location = resp.env.response_headers["location"]
          arrangement_version_url(location, media_version)
        end
      end
    end

    def arrangement_version_url(location, media_version)
      uri = URI.parse(location)
      path = uri.path.split("/")
      ext = File.extname(path.last)
      filename = File.basename(path.last, ext) + "_" + media_version + File.extname(path.last)
      uri.path = (path[0..-2] + [filename]).join("/")
    end

    def enclosure_url
      url = EnclosureUrlBuilder.new.base_enclosure_url(
        feeder_episode.podcast,
        feeder_episode,
        private_feed
      )
      EnclosureUrlBuilder.mark_authorized(url, private_feed)
    end

    def timings
      feeder_episode.media[0..-2].map(&:duration)
    end

    def pre_after_original?(placement)
      sections = placement.zones.split { |z| z[:type] == "original" }
      sections[1].any? { |z| %w[ad house].include?(z[:type]) && z[:id].match(/pre/) }
    end

    def post_before_original?(placement)
      sections = placement.zones.split { |z| z[:type] == "original" }
      sections[-2].any? { |z| %w[ad house].include?(z[:type]) && z[:id].match(/post/) }
    end
  end
end
