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
      create_apple_episodes = episodes_to_sync.select(&:apple_new?)
      update_apple_episodes = episodes_to_sync.select(&:apple_persisted?)

      Apple::Episode.create_episodes(api, create_apple_episodes)
      Apple::Episode.update_episodes(api, update_apple_episodes)

      show.reload
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

      # only create if needed
      create_podcast_containers!

      # success
      SyncLog.create!(feeder_id: feed.id, feeder_type: "f", external_id: show.id)
    rescue Apple::ApiError => _e
      SyncLog.create!(feeder_id: feed.id, feeder_type: "f")
    end

    def podcast_container_url(vendor_id)
      api.join_url("podcastContainers?filter[vendorId]=" + vendor_id).to_s
    end

    def get_podcast_containers
      resp =
        api.bridge_remote("getPodcastContainers", get_podcast_containers_bridge_params)

      api.unwrap_response(resp)
    end

    def get_podcast_containers_bridge_params
      raise "Unknown show" unless show.id.present?

      episodes_to_sync.map do |ep|
        {
          apple_episode_id: ep.id,
          api_url: podcast_container_url(ep.audio_asset_vendor_id),
          api_config: {}
        }
      end
    end

    def create_podcast_containers!
      existing_by_episode_id = episodes_to_sync.map(&:id).to_set

      binding.pry
      api_resp =
        api.bridge_remote("createPodcastContainers",
                          create_podcast_containers_bridge_params.
                            reject { |row| existing_by_episode_id.include?(row[:episode_id]) })

      # TODO: error handling
      new_containers_response = api.unwrap_response(api_resp)

      # Make sure we have local copies of the remote metadata At this point and
      # errors should be resolved and we should have then intended set of
      # podcast containers created (`create_metadata`)

      new_containers_response.map do |row|
        ep = find_episode(row["episode_id"])
        puts resp
        external_id = row["podcast_container_response"]["data"]["id"]

        pc = Apple::PodcastContainer.find_or_create!(episode_id: ep.feeder_id,
                                                     external_id: external_id,
                                                     api_response: resp)
        SyncLog.create!(feeder_id: pc.id, feeder_type: "c", external_id: external_id)
      end
    end

    def create_podcast_containers_bridge_params
      raise "Missing Show!" unless show.id.present?

      episodes_to_sync.
        map do |ep|
        {
          episode_id: ep.id,
          api_url: api.join_url("podcastContainers").to_s,
          api_parameters: podcast_container_create_parameters(ep.audio_asset_vendor_id)
        }
      end
    end

    def podcast_container_create_parameters(audio_asset_vendor_id)
      {
        'data': {
          'type': "podcastContainers",
          'attributes': {
            'vendorId': audio_asset_vendor_id
          }
        }
      }
    end
  end
end
