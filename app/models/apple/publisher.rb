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
        Rails.logger.info("Syncing Episode Guid: #{episode.episode.guid}")

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
      create_podcast_containers!
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
      create_metadata = create_episode_asset_container_metadata

      existing_containers = get_episode_asset_container_metadata
      existing_by_episode_id = existing_containers.map { |r| r[:apple_episode_id] }.to_set

      api_resp =
        api.bridge_remote("createPodcastContainers",
                          create_metadata.reject { |row| existing_by_episode_id.include?(row["episode_id"]) })

      # TODO: error handling
      _new_containers_response = api.unwrap_response(api_resp)

      # Make sure we have local copies of the remote metadata At this point and
      # errors should be resolved and we should have then intended set of
      # podcast containers created (`create_metadata`)

      create_metadata.map do |row|
        ep = find_episode(row["episode_id"])
        puts resp
        external_id = row["podcast_container_response"]["data"]["id"]

        pc = Apple::PodcastContainer.find_or_create!(episode_id: ep.feeder_id,
                                                     external_id: external_id,
                                                     api_response: resp)
        SyncLog.create!(feeder_id: pc.id, feeder_type: "c", external_id: external_id)
      end
    end

    def create_episode_asset_container_metadata
      raise "Missing Show!" unless show.id.present?

      episodes_to_sync.
        map do |ep|
        {
          apple_episode_id: ep.id,
          podcast_containers_url: api.join_url("podcastContainers").to_s,
          podcast_containers_create_parameters: ep.podcast_container_create_parameters
        }
      end
    end
  end
end
