# frozen_string_literal: true

module Apple
  class Show < Integrations::Base::Show
    include Apple::ApiResponse

    attr_reader :api

    def self.apple_shows_json(api)
      api.get_paged_collection("shows")
    end

    def self.apple_episode_json(api, show_id)
      api.get_paged_collection("shows/#{show_id}/episodes")
    end

    def self.connect_existing(apple_show_id, delegated_delivery_config)
      public_feed = delegated_delivery_config.public_feed

      # TODO: remove guard against transitional data
      unless public_feed.present?
        Rails.logger.warn(
          "Apple::DelegatedDeliveryConfig#public_feed is empty; using legacy public feed",
          delegated_delivery_config_id: delegated_delivery_config.id,
          podcast_id: delegated_delivery_config.podcast_id
        )
        public_feed = delegated_delivery_config.legacy_public_feed
      end

      raise "Missing Apple public feed" unless public_feed

      if (sl = SyncLog.apple.find_by(feeder_id: public_feed.id, feeder_type: :feeds))
        if apple_show_id.blank?
          return sl.destroy!
        elsif sl.external_id != apple_show_id
          sl.update!(external_id: apple_show_id)
        end
      else
        SyncLog.log!(
          integration: :apple,
          feeder_id: public_feed.id,
          feeder_type: :feeds,
          sync_completed_at: Time.now.utc,
          external_id: apple_show_id
        )
      end

      api = Apple::Api.from_delegated_delivery_config(delegated_delivery_config)
      new(api: api,
        public_feed: public_feed,
        private_feed: delegated_delivery_config.private_feed)
    end

    def self.get_show(api, show_id)
      resp = api.get("shows/#{show_id}")

      api.unwrap_response(resp)
    end

    def self.from_podcast(podcast)
      from_delegated_delivery_config(podcast.delegated_delivery_config)
    end

    def inspect
      "#<Apple:Show:#{object_id} show_id=#{try(:apple_id) || "nil"}>"
    end

    def self.from_delegated_delivery_config(delegated_delivery_config)
      api = Apple::Api.from_delegated_delivery_config(delegated_delivery_config)

      new(api: api,
        public_feed: delegated_delivery_config.public_feed,
        private_feed: delegated_delivery_config.private_feed,
        delegated_delivery_config: delegated_delivery_config)
    end

    def initialize(api:, public_feed:, private_feed:, delegated_delivery_config: nil)
      @private_feed = private_feed
      @public_feed = public_feed
      @api = api
      @delegated_delivery_config = delegated_delivery_config
    end

    # Gate on enclosure_ready? to prevent medialess drafts from
    # reaching probe_source_file_metadata.
    def draft_upload_candidates
      @draft_upload_candidates ||=
        begin
          draft_ids = Set.new(
            private_feed.integration_draft_episodes
              .includes(:contents)
              .select { |ep| ep.enclosure_ready?(true) }
              .map(&:id)
          )

          podcast_episodes
            .filter { |e| draft_ids.include?(e.feeder_episode.id) }
        end
    end

    def reload
      @draft_upload_candidates = nil
      @apple_episode_json = nil
      @podcast_feeder_episodes = nil
      @podcast_episodes = nil
      @episodes = nil
      @episode_ids = nil
      @find_episode = nil
      @apple_id_to_apple_json = nil
      @guid_to_apple_json = nil
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
      if @delegated_delivery_config&.routing_source == :show_feed_binding
        bound_show_id = @delegated_delivery_config.apple_show_id
        return bound_show_id if bound_show_id.present?

        Rails.logger.error("Apple binding routing requested a show ID but none was present; falling back to sync log",
          {delegated_delivery_config_id: @delegated_delivery_config.id,
           podcast_id: @delegated_delivery_config.podcast_id,
           routing_source: :show_feed_binding,
           show_feed_binding_id: @delegated_delivery_config.show_feed_binding_id})
      end

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
        apple_json = fetch_or_create_show
        remote_apple_id = apple_json.dig("api_response", "val", "data", "id")
        raise "Missing remote Apple show id" unless remote_apple_id.present?
        if apple_id.present? && remote_apple_id.to_s != apple_id.to_s
          raise "Apple show id mismatch: configured=#{apple_id.inspect}, response=#{remote_apple_id.inspect}"
        end

        sync = log_sync!(remote_apple_id, apple_json)
        public_feed.reload
        sync
      end
    end

    def create_show!
      data = show_data(create_attributes)
      Rails.logger.info("Creating show", show_data: data)
      resp = api.post("shows", data)

      api.response!(resp)
    end

    def fetch_or_create_show
      if apple_id.present?
        fetch_show
      else
        create_show!
      end
    end

    def fetch_show
      resp = api.get("shows/#{apple_id}")
      api.response!(resp)
    end

    def log_sync!(remote_apple_id, apple_json)
      if (log = sync_log)
        log.update!(external_id: remote_apple_id, api_response: apple_json, updated_at: Time.now.utc)
        log
      else
        SyncLog.log!(
          integration: :apple,
          feeder_id: public_feed.id,
          feeder_type: :feeds,
          external_id: remote_apple_id,
          api_response: apple_json
        )
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
