# frozen_string_literal: true

module Apple
  class PodcastContainer < ActiveRecord::Base
    include Apple::ApiResponse

    serialize :api_response, JSON

    has_many :podcast_deliveries
    has_many :podcast_delivery_files, through: :podcast_deliveries
    belongs_to :episode, class_name: "::Episode"

    FILE_STATUS_SUCCESS = "In Asset Repository"
    FILE_ASSET_ROLE_PODCAST_AUDIO = "PodcastSourceAudio"

    def self.update_podcast_container_file_metadata(api, episodes)
      containers = episodes.map(&:podcast_container)
      raise "Missing podcast container for episode" if containers.any?(&:nil?)

      containers_by_id = containers.map { |c| [c.id, c] }.to_h

      api.bridge_remote_and_retry!("headFileSizes", containers.map(&:head_file_size_bridge_params))
        .map do |row|
        content_length = row.dig("api_response", "val", "data", "content-length")

        podcast_container_id = row["request_metadata"]["podcast_container_id"]

        container = containers_by_id.fetch(podcast_container_id)
        container.source_size = content_length

        container.save!
        container
      end
    end

    def self.poll_podcast_container_state(api, episodes)
      results = get_podcast_containers_via_episodes(api, episodes)

      join_on_apple_episode_id(episodes, results).each do |(ep, row)|
        upsert_podcast_container(ep, row)
      end
    end

    def self.create_podcast_containers(api, episodes)
      episodes_to_create = episodes.reject { |ep| ep.podcast_container.present? }

      new_containers_response =
        api.bridge_remote_and_retry!("createPodcastContainers",
          create_podcast_containers_bridge_params(api, episodes_to_create))

      join_on_apple_episode_id(episodes_to_create, new_containers_response).each do |ep, row|
        upsert_podcast_container(ep, row)
      end

      episodes_to_create
    end

    def self.upsert_podcast_container(episode, row)
      external_id = row.dig("api_response", "val", "data", "id")

      (pc, action) =
        if (pc = where(apple_episode_id: episode.apple_id,
          external_id: external_id,
          episode_id: episode.feeder_id,
          vendor_id: episode.audio_asset_vendor_id).first)

          pc.update(api_response: row,
            source_url: episode.enclosure_url,
            source_filename: episode.enclosure_filename,
            updated_at: Time.now.utc)
          [pc, :updated]
        else
          pc = create!(api_response: row,
            apple_episode_id: episode.apple_id,
            external_id: external_id,
            source_filename: episode.enclosure_filename,
            source_url: episode.enclosure_url,
            vendor_id: episode.audio_asset_vendor_id,
            episode_id: episode.feeder_id)
          [pc, :created]
        end

      Rails.logger.info("#{action} local podcast container",
        {podcast_container_id: pc.id,
         action: action,
         external_id: external_id,
         feeder_episode_id: episode.feeder_id})

      # reset the episode's podcast container cached value
      episode.feeder_episode.reload_apple_podcast_container

      SyncLog.create!(feeder_id: pc.id, feeder_type: :podcast_containers, external_id: external_id)

      pc
    end

    def self.get_podcast_containers_via_episodes(api, episodes)
      # Fetch the podcast containers from the episodes side of the API
      response =
        api.bridge_remote_and_retry!("getPodcastContainers", get_podcast_containers_bridge_params(api, episodes))

      # Rather than mangling and persisting the enumerated view of the containers in the episodes,
      # just re-fetch the podcast containers from the non-list podcast container endpoint
      formatted_bridge_params =
        join_on_apple_episode_id(episodes, response).map do |(episode, row)|
          get_urls_for_episode_podcast_containers(api, row).map do |url|
            get_podcast_containers_bridge_param(episode.apple_id, url)
          end
        end

      formatted_bridge_params = formatted_bridge_params.flatten

      api.bridge_remote_and_retry!("getPodcastContainers",
        formatted_bridge_params)
    end

    def self.get_urls_for_episode_podcast_containers(api, episode_podcast_containers_json)
      containers_json = episode_podcast_containers_json["api_response"]["val"]["data"]
      raise "Unsupported number of podcast containers for episode: #{ep.feeder_id}" if containers_json.length > 1

      containers_json.map do |podcast_container_json|
        api.join_url("podcastContainers/#{podcast_container_json["id"]}").to_s
      end
    end

    def self.get_podcast_containers_bridge_params(api, episodes)
      episodes.map do |ep|
        get_podcast_containers_bridge_param(ep.apple_id, podcast_container_url(api, ep))
      end
    end

    def self.get_podcast_containers_bridge_param(apple_episode_id, api_url)
      {
        request_metadata: {apple_episode_id: apple_episode_id},
        api_url: api_url,
        api_parameters: {}
      }
    end

    def self.create_podcast_containers_bridge_params(api, episodes)
      episodes
        .map do |ep|
        {
          request_metadata: {apple_episode_id: ep.apple_id},
          api_url: api.join_url("podcastContainers").to_s,
          api_parameters: podcast_container_create_parameters(ep)
        }
      end
    end

    def self.podcast_container_create_parameters(episode)
      {
        data: {
          type: "podcastContainers",
          attributes: {
            vendorId: episode.audio_asset_vendor_id
          }
        }
      }
    end

    def self.podcast_containers_parameters(episode)
      {
        data: {
          type: "podcastContainers",
          attributes: {
            vendorId: episode.audio_asset_vendor_id,
            id: episode.podcast_container.external_id
          }
        }
      }
    end

    def self.podcast_container_url(api, episode)
      raise "Missing episode audio vendor id" unless episode.audio_asset_vendor_id.present?

      api.join_url("podcastContainers?filter[vendorId]=#{episode.audio_asset_vendor_id}").to_s
    end

    def head_file_size_bridge_params
      {
        request_metadata: {
          apple_episode_id: apple_episode_id,
          podcast_container_id: id
        },
        api_url: source_url,
        api_parameters: {}
      }
    end

    def podcast_deliveries_url
      apple_data.dig("relationships", "podcastDeliveries", "links", "related")
    end

    def podcast_container_id
      id
    end

    def files
      apple_attributes.dig("files")
    end

    def has_podcast_audio?
      return false if files.blank?

      files.any? do |file|
        # Retrieve the file status from the podcast container's files attribute
        file["status"] == FILE_STATUS_SUCCESS && file["assetRole"] == FILE_ASSET_ROLE_PODCAST_AUDIO
      end
    end

    def missing_podcast_audio?
      !has_podcast_audio?
    end

    def needs_delivery?
      # TODO: Overwriting the podcast audio with another file
      missing_podcast_audio? && podcast_deliveries.empty?
    end
  end
end
