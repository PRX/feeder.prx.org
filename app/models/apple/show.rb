# frozen_string_literal: true

module Apple
  class Show
    include Apple::ApiResponse

    attr_reader :public_feed,
      :private_feed,
      :api

    def self.apple_episode_json(api, show_id)
      api.get_paged_collection("shows/#{show_id}/episodes")
    end

    def self.connect_existing(apple_show_id, apple_config)
      api = Apple::Api.from_apple_config(apple_config)

      SyncLog.log!(feeder_id: apple_config.public_feed.id,
        feeder_type: :feeds,
        sync_completed_at: Time.now.utc,
        external_id: apple_show_id)

      new(api: api,
        public_feed: apple_config.public_feed,
        private_feed: apple_config.private_feed)
    end

    def self.get_show(api, show_id)
      resp = api.get("shows/#{show_id}")

      api.unwrap_response(resp)
    end

    def inspect
      "#<Apple:Show:#{object_id} show_id=#{try(:apple_id) || "nil"}>"
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

    def podcast_feeder_episodes
      @podcast_feeder_episodes ||=
        podcast.episodes.reset.with_deleted
    end

    # All the episodes -- including deleted and unpublished
    def podcast_episodes
      @podcast_episodes ||= podcast_feeder_episodes.map { |e| Apple::Episode.new(api: api, show: self, feeder_episode: e) }
    end

    # Does not include deleted episodes
    def episodes
      raise "Missing apple show id" unless apple_id.present?

      @episodes ||= begin
        feed_episode_ids = Set.new(private_feed.feed_episodes.map(&:id))

        podcast_episodes
          .filter { |e| feed_episode_ids.include?(e.feeder_episode.id) }
      end
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
  end
end
