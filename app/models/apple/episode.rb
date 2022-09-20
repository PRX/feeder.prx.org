# frozen_string_literal: true

require "uri"

module Apple
  class Episode
    attr_reader :show, :feeder_episode, :api

    def self.create_episodes(api, episodes)
      return if episodes.empty?

      resp =
        api.bridge_remote("createEpisodes", episodes.map(&:create_episode_bridge_params))

      # TODO: handle errors
      episode_bridge_results = api.unwrap_response(resp)
      insert_sync_logs(episodes, episode_bridge_results)
    end

    def self.update_episodes(api, episodes)
      return if episodes.empty?

      resp =
        api.bridge_remote("updateEpisodes", episodes.map(&:update_episode_bridge_params))

      # TODO: handle errors
      episode_bridge_results = api.unwrap_response(resp)
      insert_sync_logs(episodes, episode_bridge_results)
    end

    def self.insert_sync_logs(episodes, results)
      episodes_by_item_guid = episodes.map { |ep| [ep.item_guid, ep] }.to_h

      results.each do |res|
        # we don't have the external ids loadded yet.
        # save an api call and redo the join like in
        apple_id = res.dig("api_response", "val", "data", "id")
        guid = res.dig("api_response", "val", "data", "attributes", "guid")
        ep = episodes_by_item_guid.fetch(guid)

        SyncLog.
          create(feeder_id: ep.feeder_episode.id, feeder_type: :episodes, external_id: apple_id)
      end
    end

    def initialize(show, episode)
      @show = show
      @feeder_episode = episode
      @api = Apple::Api.from_env
    end

    def feeder_id
      feeder_episode.id
    end

    def enclosure_url
      feeder_episode.enclosure_url
    end

    def enclosure_filename
      feeder_episode.enclosure_filename
    end

    def json
      eps = show.get_episodes

      eps.detect { |ep| ep["attributes"]["guid"] == feeder_episode.item_guid }
    end

    alias_method :apple_json, :json

    def completed_sync_log
      SyncLog.
        episodes.
        complete.
        latest.
        where(feeder_id: feeder_episode.id, feeder_type: "e").
        first
    end

    def apple_persisted?
      apple_json.present?
    end

    def apple_new?
      !apple_persisted?
    end

    def apple_only?
      feeder_episode.apple_only?
    end

    def item_guid
      feeder_episode.item_guid
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
      feeder_episode.apple?
    end

    def apple_only?
      feeder_episode.apple_only?
    end

    def create_episode_bridge_params
      {
        api_url: api.join_url("episodes").to_s,
        api_parameters: episode_create_parameters,
      }
    end

    def episode_create_parameters
      explicit = feeder_episode.explicit.present? && feeder_episode.explicit == "true"

      {
        data:
        {
          type: "episodes",
          attributes: {
            guid: feeder_episode.item_guid,
            title: feeder_episode.title,
            originalReleaseDate: feeder_episode.published_at.utc.iso8601,
            description: feeder_episode.description || feeder_episode.subtitle,
            websiteUrl: feeder_episode.url,
            explicit: explicit,
            episodeNumber: feeder_episode.episode_number,
            seasonNumber: feeder_episode.season_number,
            episodeType: feeder_episode.itunes_type.upcase,
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
        api_parameters: update_episode_parameters,
      }
    end

    def update_episode_parameters
      data = episode_create_parameters

      data[:data][:id] = id
      data[:data][:attributes].delete(:guid)
      data[:data][:relationships].delete(:show)

      data
    end

    def head_file_size_bridge_params
      {
        episode_id: apple_id,
        api_url: feeder_episode.enclosure_url,
        api_parameters: {},
      }
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

    def apple_id
      apple_json&.dig("id")
    end

    def id
      apple_id
    end

    def podcast_container
      # TODO: differentiate these by container type: audio versus images
      Apple::PodcastContainer.find_by(episode_id: feeder_episode.id)
    end
  end
end
