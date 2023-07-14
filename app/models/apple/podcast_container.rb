# frozen_string_literal: true

module Apple
  class PodcastContainer < ApplicationRecord
    include Apple::ApiResponse

    serialize :api_response, JSON

    default_scope { includes(:apple_sync_log) }

    has_one :apple_sync_log, -> { podcast_containers }, foreign_key: :feeder_id, class_name: "SyncLog"
    has_many :podcast_deliveries, dependent: :destroy
    has_many :podcast_delivery_files, through: :podcast_deliveries
    belongs_to :episode, class_name: "::Episode"

    alias_attribute :deliveries, :podcast_deliveries
    alias_attribute :delivery_files, :podcast_delivery_files

    FILE_STATUS_SUCCESS = "In Asset Repository"
    FILE_ASSET_ROLE_PODCAST_AUDIO = "PodcastSourceAudio"
    SOURCE_URL_EXP_BUFFER = 10.minutes

    def self.reset_source_file_metadata(episodes)
      episodes = episodes.select { |ep| ep.podcast_container.present? }
      episodes = episodes.select { |ep| ep.podcast_container.needs_delivery? }

      episodes.map do |episode|
        container = episode.container

        Rails.logger.info("Resetting source url for podcast container",
          podcast_container_id: container.id,
          source_size: container.source_size,
          source_url: container.source_url)

        # Back to DTR to pick up fresh arrangements:
        container.reset_source_metadata!(episode)
        episode.feeder_episode.apple_mark_for_reupload!
      end.compact
    end

    def self.probe_source_file_metadata(api, episodes)
      containers = episodes.map(&:podcast_container)
      raise "Missing podcast container for episode" if containers.any?(&:nil?)
      containers = containers.filter(&:needs_file_metadata?)

      containers_by_id = containers.map { |c| [c.id, c] }.to_h

      api.bridge_remote_and_retry!("headFileSizes", containers.map(&:head_file_size_bridge_params))
        .map do |row|
        content_length = row.dig("api_response", "val", "data", "headers", "content-length")
        cdn_url = row.dig("api_response", "val", "data", "redirect_chain_end_url")
        raise "Missing content-length in response" if content_length.blank?
        raise "Missing cdn_url in response" if cdn_url.blank?

        podcast_container_id = row["request_metadata"]["podcast_container_id"]

        container = containers_by_id.fetch(podcast_container_id)
        container.source_size = content_length
        container.source_url = cdn_url

        container.save!
        container
      end
    end

    def self.poll_podcast_container_state(api, episodes)
      results = get_podcast_containers_via_episodes(api, episodes)

      join_on_apple_episode_id(episodes, results, left_join: true).each do |(ep, row)|
        next if row.nil?
        apple_id = row.dig("api_response", "val", "data", "id")
        raise "missing apple id!" unless apple_id.present?

        upsert_podcast_container(ep, row)
      end
    end

    def self.create_podcast_containers(api, episodes)
      # There is a 1:1 relationship between episodes and podcast containers w/
      # key contraints on the episodes vendorId -- and you cannot destroy a
      # podcast container.
      # We should have a local record of the podcast container, per the poll
      # method above.
      episodes_to_create = episodes.reject { |ep| ep.has_container? }

      new_containers_response =
        api.bridge_remote_and_retry!("createPodcastContainers",
          create_podcast_containers_bridge_params(api, episodes_to_create), batch_size: Api::DEFAULT_WRITE_BATCH_SIZE)

      join_on_apple_episode_id(episodes_to_create, new_containers_response).each do |ep, row|
        upsert_podcast_container(ep, row)
      end

      episodes_to_create
    end

    def self.upsert_podcast_container(episode, row)
      external_id = row.dig("api_response", "val", "data", "id")
      raise "Missing external_id in response" if external_id.blank?

      (pc, action) =
        if (pc = where(apple_episode_id: episode.apple_id,
          external_id: external_id,
          episode_id: episode.feeder_id,
          vendor_id: episode.audio_asset_vendor_id).first)

          pc.touch
          [pc, :updated]
        else
          pc = create!(apple_episode_id: episode.apple_id,
            external_id: external_id,
            vendor_id: episode.audio_asset_vendor_id,
            episode_id: episode.feeder_id)

          [pc, :created]
        end

      Rails.logger.info("#{action} local podcast container",
        {podcast_container_id: pc.id,
         action: action,
         external_id: external_id,
         feeder_episode_id: episode.feeder_id})

      SyncLog.log!(feeder_id: pc.id, feeder_type: :podcast_containers, external_id: external_id, api_response: row)

      # reset the episode's podcast container cached value
      pc.reload if action == :updated
      episode.feeder_episode.reload

      pc
    end

    def self.get_podcast_containers_via_episodes(api, episodes)
      # Fetch the podcast containers from the episodes side of the API
      response =
        api.bridge_remote_and_retry!("getPodcastContainers", get_podcast_containers_bridge_params(api, episodes), batch_size: 1)

      # Rather than mangling and persisting the enumerated view of the containers in the episodes,
      # just re-fetch the podcast containers from the non-list podcast container endpoint
      formatted_bridge_params =
        join_on_apple_episode_id(episodes, response).map do |(episode, row)|
          get_urls_for_episode_podcast_containers(api, row).map do |url|
            get_podcast_containers_bridge_param(episode.apple_id, url)
          end
        end

      formatted_bridge_params = formatted_bridge_params.flatten

      api.bridge_remote_and_retry!("getPodcastContainers", formatted_bridge_params, batch_size: 2)
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
        api_url: source_url || enclosure_url,
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
      # Handle the case where the podcast container *does* have podcast audio,
      # but doesn't have any podcast deliveries / files. This is a weird edge
      # case but it amounts to checking the deliveries to see if any are there.
      # If there are no deliveries, then the code that polls/checks the delivery
      # status will fail. So we need to create a delivery.
      podcast_deliveries.empty?
    end

    def reset_source_metadata!(apple_ep)
      update!(
        source_url: nil,
        source_size: nil,
        source_filename: apple_ep.enclosure_filename,
        enclosure_url: apple_ep.enclosure_url
      )
    end

    def needs_file_metadata?
      source_url.nil? || source_size.nil? || source_filename.nil?
    end
  end
end
