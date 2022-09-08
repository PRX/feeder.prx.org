# frozen_string_literal: true

module Apple
  class Publisher
    attr_reader :feed,
                :api,
                :show

    def initialize(feed)
      @feed = feed
      @api = Apple::Api.from_env
      @show = Apple::Show.new(@feed)
    end

    def podcast
      feed.podcast
    end

    def episodes_to_sync
      @episodes ||= feed.
                    apple_filtered_episodes.map do |ep|
        Apple::Episode.new(show, ep)
      end
    end

    def episode_ids
      @episode_ids ||= episodes_to_sync.map(&:id).sort
    end

    def find_episode(id)
      @find_episode ||=
        episodes_to_sync.map { |e| [e.id, e] }.to_h

      @find_episode.fetch(id)
    end

    def sync_episodes!
      episodes_to_sync.each do |episode|
        Rails.logger("Syncing Episode Guid: #{episode.episode.guid}")

        episode.sync!
      end
    end

    def zip_episode_results(res)
      zipped = res.map do |r|
        [find_episode(r["apple_episode_id"]).id, r]
      end.to_h

      zipped
    end

    def publish!
      show.sync!

      sync_episodes!

      show.reload

      # sync the containers
      zip_episode_results(get_podcast_containers)

      # new containers
      new_containers_response = create_podcast_containers!

      new_containers_response.map do |resp|
        ep = find_episode(resp["apple_episode_id"])
        external_id = resp["podcast_container_response"]["data"]["id"]

        Apple::PodcastContainer.create!(episode_id: ep.feeder_id,
                                        external_id: external_id,
                                        api_response: resp)
      end
    rescue Apple::ApiError => _e
      SyncLog.create!(feeder_id: feed.id, feeder_type: "f")
    end

    def episode_podcast_container_url(vendor_id)
      api.join_url("podcastContainers?filter[vendorId]=" + vendor_id).to_s
    end

    def get_podcast_containers
      resp =
        api.bridge_remote("getPodcastContainers", get_episode_asset_container_metadata)

      api.unwrap_response(resp)
    end

    def get_episode_asset_container_metadata
      raise "Unknown show" unless show.id.present?

      episodes_to_sync.map do |ep|
        {
          apple_episode_id: ep.id,
          audio_asset_vendor_id: ep.audio_asset_vendor_id,
          podcast_containers_url: ep.podcast_container_url
        }
      end
    end

    def create_podcast_containers!
      resp =
        api.bridge_remote("createPodcastContainers", create_episode_asset_container_metadata)

      api.unwrap_response(resp)
    end

    def create_episode_asset_container_metadata
      return unless show.id.present?

      episodes_to_sync.map do |ep|
        {
          apple_episode_id: ep.id,
          podcast_containers_url: api.join_url("podcastContainers").to_s,
          podcast_containers_create_parameters: ep.podcast_container_create_parameters
        }
      end
    end
  end
end
