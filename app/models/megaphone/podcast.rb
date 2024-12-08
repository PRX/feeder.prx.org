module Megaphone
  class Podcast < Integrations::Base::Show
    include Megaphone::Model

    # Required attributes for a create
    # external_id is not required by megaphone, but we need it to be set!
    CREATE_REQUIRED = %i[title subtitle summary itunes_categories language external_id]

    # Other attributes available on create
    CREATE_ATTRIBUTES = CREATE_REQUIRED + %i[link copyright author background_image_file_url
      explicit owner_name owner_email slug original_rss_url itunes_identifier podtrac_enabled
      google_play_identifier episode_limit podcast_type advertising_tags excluded_categories]

    # Update also allows the span opt in
    UPDATE_ATTRIBUTES = CREATE_ATTRIBUTES + %i[span_opt_in]

    # Deprecated, so we shouldn't rely on these, but they show up as attributes
    DEPRECATED = %i[category redirect_url itunes_active redirected_at itunes_rating
      google_podcasts_identifier stitcher_identifier]

    # All other attributes we might expect back from the Megaphone API
    # (some documented, others not so much)
    OTHER_ATTRIBUTES = %i[id created_at updated_at image_file uid network_id recurring_import
      episodes_count spotify_identifier default_ad_settings iheart_identifier feed_url
      default_pre_count default_post_count cloned_feed_urls ad_free_feed_urls main_feed ad_free]

    ALL_ATTRIBUTES = (UPDATE_ATTRIBUTES + DEPRECATED + OTHER_ATTRIBUTES)

    attr_accessor(*ALL_ATTRIBUTES)

    validates_presence_of CREATE_REQUIRED

    validates_presence_of :id, on: :update

    validates_absence_of :id, on: :create

    def self.find_by_feed(feed)
      podcast = new_from_feed(feed)
      sync_log = podcast.public_feed.sync_log(:megaphone)
      mp = podcast.find_by_megaphone_id(sync_log&.external_id)
      mp ||= podcast.find_by_guid(feed.podcast.guid)
      mp
    end

    def self.new_from_feed(feed)
      podcast = Megaphone::Podcast.new(attributes_from_feed(feed))
      podcast.private_feed = feed
      podcast.config = feed.config
      podcast
    end

    def self.attributes_from_feed(feed)
      podcast = feed.podcast
      itunes_categories = feed.itunes_categories.present? ? feed.itunes_categories : podcast.itunes_categories
      {
        title: feed.title || podcast.title,
        subtitle: feed.subtitle || podcast.subtitle,
        summary: feed.description || podcast.description,
        itunes_categories: (itunes_categories || []).map(&:name),
        language: (podcast.language || "en-us").split("-").first,
        link: podcast.link,
        copyright: podcast.copyright,
        author: podcast.author_name,
        background_image_file_url: feed.ready_itunes_image || podcast.ready_itunes_image,
        explicit: podcast.explicit,
        owner_name: podcast.owner_name,
        owner_email: podcast.owner_email,
        slug: feed.slug,
        # itunes_identifier: ????? TBD,
        # handle prefix values in dt rss rendering of enclosure urls
        podtrac_enabled: false,
        episode_limit: feed.display_episodes_count,
        external_id: podcast.guid,
        podcast_type: podcast.itunes_type,
        advertising_tags: podcast.categories
        # set in augury, can we get it here?
        # excluded_categories: ????? TBD,
      }
    end

    def public_feed
      private_feed.podcast&.public_feed
    end

    def build_integration_episode(feeder_episode)
      Megaphone::Episode.new_from_episode(self, feeder_episode)
    end

    def updated_at=(d)
      d = Time.parse(d) if d.is_a?(String)
      @updated_at = d
    end

    def list
      self.api_response = api.get("podcasts")
      Megaphone::PagedCollection.new(Megaphone::Podcast, api_response)
    end

    def find_by_guid(guid = podcast.guid)
      return nil if guid.blank?
      self.api_response = api.get("podcasts", externalId: guid)
      handle_response(api_response)
    end

    def find_by_megaphone_id(mpid = id)
      return nil if mpid.blank?
      self.api_response = api.get("podcasts/#{mpid}")
      handle_response(api_response)
    end

    def create!
      validate!(:create)
      body = as_json(only: CREATE_ATTRIBUTES.map(&:to_s))
      self.api_response = api.post("podcasts", body)
      handle_response(api_response)
      update_sync_log
      self
    end

    def update!(feed = nil)
      if feed
        self.attributes = self.class.attributes_from_feed(feed)
      end
      validate!(:update)
      body = as_json(only: UPDATE_ATTRIBUTES.map(&:to_s))
      self.api_response = api.put("podcasts/#{id}", body)
      handle_response(api_response)
      update_sync_log
      self
    end

    def handle_response(api_response)
      if (item = (api_response[:items] || []).first)
        self.attributes = item.slice(*ALL_ATTRIBUTES)
        self
      end
    end

    def update_sync_log
      SyncLog.log!(
        integration: :megaphone,
        feeder_type: :feeds,
        feeder_id: public_feed.id,
        external_id: id,
        api_response: api_response_log_item
      )
    end
  end
end
