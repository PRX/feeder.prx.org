# frozen_string_literal: true

module Apple
  class Show < Integrations::Base::Show
    include Apple::ApiResponse

    attr_reader :public_feed,
      :private_feed,
      :api

    def self.apple_shows_json(api)
      api.get_paged_collection("shows")
    end

    def self.apple_episode_json(api, show_id)
      api.get_paged_collection("shows/#{show_id}/episodes")
    end

    def self.connect_existing(apple_show_id, apple_config)
      if (sl = SyncLog.find_by(feeder_id: apple_config.public_feed.id, feeder_type: :feeds))
        if apple_show_id.blank?
          return sl.destroy!
        elsif sl.external_id != apple_show_id
          sl.update!(external_id: apple_show_id)
        end
      else
        SyncLog.log!(feeder_id: apple_config.public_feed.id,
          feeder_type: :feeds,
          sync_completed_at: Time.now.utc,
          external_id: apple_show_id)
      end

      api = Apple::Api.from_apple_config(apple_config)
      new(api: api,
        public_feed: apple_config.public_feed,
        private_feed: apple_config.private_feed)
    end

    def self.get_show(api, show_id)
      resp = api.get("shows/#{show_id}")

      api.unwrap_response(resp)
    end

    def self.from_podcast(podcast)
      apple_config = podcast.apple_config
      api = Apple::Api.from_apple_config(apple_config)

      new(api: api,
        public_feed: apple_config.public_feed,
        private_feed: apple_config.private_feed)
    end

    def inspect
      "#<Apple:Show:#{object_id} show_id=#{try(:apple_id) || "nil"}>"
    end

    def self.from_apple_config(apple_config)
      api = Apple::Api.from_apple_config(apple_config)

      new(api: api,
        public_feed: apple_config.public_feed,
        private_feed: apple_config.private_feed)
    end

    def initialize(api:, public_feed:, private_feed:)
      @private_feed = private_feed
      @public_feed = public_feed
      @api = api
    end

    def reload
      @apple_episode_json = nil
      @podcast_feeder_episodes = nil
      @podcast_episodes = nil
      @episodes = nil
      @episode_ids = nil
      @find_episode = nil
    end

    def podcast
      public_feed.podcast
    end

    def feed_published_url
      raise "missing token for private feed" if public_feed.private? && public_feed.tokens.empty?

      public_feed.published_url(true)
    end

    def update_attributes
      create_attributes.except(:releaseFrequency)
    end

    def create_attributes
      {
        kind: "RSS",
        rssUrl: feed_published_url,
        releaseFrequency: "WEEKLY",
        thirdPartyRights: "HAS_RIGHTS_TO_THIRD_PARTY_CONTENT"
      }
    end

    def show_data(attributes, id: nil)
      res =
        {
          data: {
            type: "shows",
            relationships: {
              allowedCountriesAndRegions: {data: api.countries_and_regions}
            },
            attributes: attributes
          }
        }
      res[:data][:id] = id if id.present?
      res
    end

    def apple_id
      sync_log&.external_id
    end

    def id
      apple_id
    end

    def sync_log
      public_feed.apple_sync_log
    end

    def apple_sync_log
      sync_log
    end

    def sync!
      Rails.logger.info("Syncing feed with Apple show", {apple_id: apple_id, public_feed_id: public_feed.id, private_feed_id: private_feed.id})
      Rails.logger.tagged("Apple::Show#sync!") do
        apple_json = create_or_update_show(sync_log)
        public_feed.reload
        SyncLog.log!(feeder_id: public_feed.id, feeder_type: :feeds, external_id: apple_json["api_response"]["val"]["data"]["id"], api_response: apple_json)
      end
    end

    def create_show!
      data = show_data(create_attributes)
      Rails.logger.info("Creating show", show_data: data)
      resp = api.post("shows", data)

      api.response(resp)
    end

    def update_show!(sync)
      Rails.logger.info("Skipping update for existing show!")
      # TODO, map out the cases where we'd actually need to update a show
      # data = show_data(update_attributes, id: apple_id)
      # Rails.logger.info("Updating show", show_data: data)
      # resp = api.patch("shows/#{sync.external_id}", data)
      #
      # api.response(resp)

      resp = api.get("shows/#{sync.external_id}")
      api.response(resp)
    end

    def create_or_update_show(sync)
      if sync.present?
        update_show!(sync)
      else
        create_show!
      end
    end

    def get_show
      raise "Missing apple show id" unless apple_id.present?

      self.class.get_show(api, apple_id)
    end

    def build_integration_episode(feeder_episode)
      Apple::Episode.new(api: api, show: self, feeder_episode: feeder_episode)
    end

    def apple_private_feed_episodes
      episodes
    end

    def episode_ids
      @episode_ids ||= episodes.map(&:id).sort
    end

    def find_episode(id)
      @find_episode ||=
        episodes.map { |e| [e.id, e] }.to_h

      @find_episode.fetch(id)
    end

    def apple_episode_json
      @apple_episode_json ||= Apple::Show.apple_episode_json(api, id)
    end

    def api_response
      public_feed.apple_sync_log&.api_response
    end

    def guid_to_apple_json(guid)
      @guid_to_apple_json ||= apple_episode_json.map do |ep_json|
        [ep_json["attributes"]["guid"], ep_json]
      end.to_h

      @guid_to_apple_json[guid]
    end

    def apple_id_to_apple_json(apple_id)
      @apple_id_to_apple_json ||= apple_episode_json.map do |ep_json|
        [ep_json["id"], ep_json]
      end.to_h

      @apple_id_to_apple_json[apple_id]
    end

    def find_apple_episode_json_by_guid(guid)
      # Because apple can use its own id to join to the RSS feed item,
      # if the feed item guid is set to the apple episode id
      guid_to_apple_json(guid) || apple_id_to_apple_json(guid)
    end
  end
end
