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

    def self.apple_staged_alternate_asset_json(api, show_id)
      api.get_paged_collection("shows/#{show_id}/stagedAlternateAssets")
    end

    def self.guid_filter(guid)
      "filter[guid]=#{ERB::Util.url_encode(guid)}"
    end

    def self.get_show(api, show_id)
      resp = api.get("shows/#{show_id}")

      api.unwrap_response(resp)
    end

    def inspect
      "#<Apple:Show:#{object_id} show_id=#{try(:apple_id) || "nil"}>"
    end

    def self.from_delegated_delivery_config(delegated_delivery_config)
      api = Apple::Api.from_delegated_delivery_config(delegated_delivery_config)

      new(api: api,
        public_feed: delegated_delivery_config.public_feed,
        private_feed: delegated_delivery_config.private_feed,
        show_feed_binding: delegated_delivery_config.show_feed_binding)
    end

    def self.from_show_feed_binding(show_feed_binding)
      apple_key = show_feed_binding.feed.podcast.apple_key
      raise "Missing Apple key for podcast" unless apple_key

      new(api: Apple::Api.from_key(apple_key),
        public_feed: show_feed_binding.feed,
        private_feed: nil,
        show_feed_binding: show_feed_binding)
    end

    def initialize(api:, public_feed:, private_feed:, show_feed_binding:)
      @private_feed = private_feed
      @public_feed = public_feed
      @api = api
      @show_feed_binding = show_feed_binding
    end

    # Gate on enclosure_ready? to prevent medialess drafts from
    # reaching probe_source_file_metadata.
    def draft_upload_candidates
      @draft_upload_candidates ||=
        begin
          draft_ids = Set.new(
            private_feed.integration_draft_episodes(:apple)
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
      @staged_alternate_asset_json = nil
      @guid_to_staged_alternate_asset_json = nil
    end

    def podcast
      public_feed.podcast
    end

    def apple_id
      @show_feed_binding.apple_show_id
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
        apple_json = fetch_show
        remote_apple_id = apple_json.dig("api_response", "val", "data", "id")
        raise "Missing remote Apple show id" unless remote_apple_id.present?
        if remote_apple_id.to_s != apple_id.to_s
          raise "Apple show id mismatch: configured=#{apple_id.inspect}, response=#{remote_apple_id.inspect}"
        end

        sync = log_sync!(remote_apple_id, apple_json)
        public_feed.reload
        sync
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

    def staged_alternate_asset_json
      @staged_alternate_asset_json ||= Apple::Show.apple_staged_alternate_asset_json(api, id)
    end

    def find_staged_alternate_asset_json_by_guid(guid)
      @guid_to_staged_alternate_asset_json ||= staged_alternate_asset_json.map do |asset_json|
        [asset_json["attributes"]["guid"], asset_json]
      end.to_h

      @guid_to_staged_alternate_asset_json[guid]
    end

    # Single-GUID lookups for polling one episode without the bulk reads.
    def find_apple_episode_json_by_guid_filter(guid)
      api.get_paged_collection("shows/#{id}/episodes?#{self.class.guid_filter(guid)}")
        .find { |ep_json| ep_json.dig("attributes", "guid") == guid }
    end

    def find_apple_episode_json_by_apple_id(apple_id)
      resp = api.get("episodes/#{ERB::Util.url_encode(apple_id)}?include=show", ignore_errors: [Apple::Api::NOT_FOUND])
      return if resp.code.to_i == Apple::Api::NOT_FOUND

      ep_json = api.unwrap_response(resp)["data"]
      ep_json if ep_json.dig("relationships", "show", "data", "id") == id
    end

    def find_staged_alternate_asset_json_by_guid_filter(guid)
      api.get_paged_collection("shows/#{id}/stagedAlternateAssets?#{self.class.guid_filter(guid)}")
        .find { |asset_json| asset_json.dig("attributes", "guid") == guid }
    end
  end
end
