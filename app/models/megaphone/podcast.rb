module Megaphone
  class Podcast
    include ActiveModel::Model
    attr_accessor :feed
    attr_writer :api

    # Required attributes for a create
    # external_id is not required by megaphone, but we need it to be set!
    CREATE_REQUIRED = %w[title subtitle summary itunes_categories language external_id]

    # Other attributes available on create
    CREATE_ATTRIBUTES = CREATE_REQUIRED + %w[link copyright author background_image_file_url
      explicit owner_name owner_email slug original_rss_url itunes_identifier podtrac_enabled
      google_play_identifier episode_limit podcast_type advertising_tags excluded_categories]

    # Update also allows the span opt in
    UPDATE_ATTRIBUTES = CREATE_ATTRIBUTES + %w[span_opt_in]

    # Deprecated, so we shouldn't rely on these, but they show up as attributes
    DEPRECATED = %w[category redirect_url itunes_active redirected_at itunes_rating
      google_podcasts_identifier stitcher_identifier]

    # All other attributes we might expect back from the Megaphone API
    # (some documented, others not so much)
    OTHER_ATTRIBUTES = %w[id created_at updated_at image_file uid network_id recurring_import
      episodes_count spotify_identifier default_ad_settings iheart_identifier feed_url
      default_pre_count default_post_count cloned_feed_urls ad_free_feed_urls main_feed ad_free]

    ALL_ATTRIBUTES = (UPDATE_ATTRIBUTES + DEPRECATED + OTHER_ATTRIBUTES)

    attr_accessor(*ALL_ATTRIBUTES)

    validates_presence_of CREATE_REQUIRED

    validates_presence_of :id, on: :update

    validates_absence_of :id, on: :create

    # initialize from attributes
    def initialize(attributes = {})
      super
    end

    def self.new_from_feed(feed)
      podcast = Megaphone::Podcast.new(attributes_from_feed(feed))
      podcast.feed = feed
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

    def list
      result = api.get("podcasts")
      Megaphone::PagedCollection.new(Megaphone::Podcast, result)
    end

    def find_by_guid
      result = api.get("podcasts", externalId: feed.podcast.guid)
      Megaphone::PagedCollection.new(Megaphone::Podcast, result)
    end

    def find_by_megaphone_id(mpid = id)
      result = api.get("podcasts/#{mpid}")
      (result[:items] || []).first
    end

    def create!
      validate!(:create)
      body = as_json.slice(*Megaphone::Podcast::CREATE_ATTRIBUTES)
      result = api.post("podcasts", body)
      self.attributes = result.slice(*Megaphone::Podcast::ALL_ATTRIBUTES)
      self
    end

    def update!
      validate!(:update)
      body = as_json.slice(*Megaphone::Podcast::UPDATE_ATTRIBUTES).to_json
      result = api.put("podcasts/#{id}", body)
      self.attributes = result.slice(*Megaphone::Podcast::ALL_ATTRIBUTES)
      self
    end

    def config
      feed.megaphone_config
    end

    def api
      @api ||= Megaphone::Api.new(token: config.token, network_id: config.network_id)
    end
  end
end
