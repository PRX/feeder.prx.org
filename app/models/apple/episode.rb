# frozen_string_literal: true

module Apple
  class Episode
    attr_reader :show, :episode, :api

    def self.create_episodes(api, episodes)
      return if episodes.empty?

      resp =
        api.bridge_remote("createEpisodes", episodes.map(&:create_episode_bridge_params))

      episode_bridge_results = api.unwrap_response(resp)

      episode_bridge_results.each { |ebr| insert_sync_logs(ebr) }
    end

    def self.update_episodes(api, episodes)
      return if episodes.empty?

      resp =
        api.bridge_remote("updateEpisodes", episodes.map(&:update_episode_bridge_params))

      episode_bridge_results = api.unwrap_response(resp)

      episode_bridge_results.each { |ebr| insert_sync_logs(ebr) }
    end

    def self.insert_sync_logs(resp)
      binding.pry
    end

    def initialize(show, episode)
      @show = show
      @episode = episode
      @api = Apple::Api.from_env
    end

    def json
      eps = show.get_episodes

      eps.detect { |ep| ep["attributes"]["guid"] == episode.item_guid }
    end

    alias_method :apple_json, :json

    def completed_sync_log
      SyncLog.
        episodes.
        complete.
        where(feeder_id: episode.id, feeder_type: "e", external_type: nil).
        order(id: :desc).
        first
    end

    def apple_persisted?
      apple_json.present?
    end

    def apple_new?
      !apple_persisted?
    end

    def create_or_update_episode!
      raise "Not for apple!" unless apple_only?

      json =
        if apple_new?
          create_episode!
        elsif apple_only?
          update_episode!
        end

      sync
    end

    def apple?
      episode.apple?
    end

    def apple_only?
      episode.apple_only?
    end

    def create_episode_bridge_params
      {
        api_url: api.join_url("episodes").to_s,
        api_parameters: episode_create_parameters,
      }
    end

    def episode_create_parameters
      explicit = episode.explicit.present? && episode.explicit == "true"

      {
        data:
        {
          type: "episodes",
          attributes: {
            guid: episode.item_guid,
            title: episode.title,
            originalReleaseDate: episode.published_at.utc.iso8601,
            description: episode.description || episode.subtitle,
            websiteUrl: episode.url,
            explicit: explicit,
            episodeNumber: episode.episode_number,
            seasonNumber: episode.season_number,
            episodeType: episode.itunes_type.upcase,
            appleHostedAudioIsSubscriberOnly: true
          },
          relationships: {
            show: { data: { type: "shows", id: show.id } }
          }
        }
      }
    end

    def update_episode_bridge_params
      {
        api_url: api.join_url("episodes/" + id).to_s,
        api_parameters: episode_create_parameters,
      }
    end

    def update_episode_parameters
      data = episode_create_parameters

      data[:data][:id] = id
      data[:data][:attributes].delete(:guid)
      data[:data][:relationships].delete(:show)

      data
    end

    def create_episode!
      self.class.create_apple_episodes([self])

      api.unwrap_response(resp)
    end

    def update_episode!
      resp = api.patch("episodes/" + id, update_episode_data)

      api.unwrap_response(resp)
    end

    def audio_asset_vendor_id
      apple_json&.dig("attributes", "appleHostedAudioAssetVendorId")
    end

    def id
      apple_json&.dig("id")
    end

    def feeder_id
      episode.id
    end
  end
end
