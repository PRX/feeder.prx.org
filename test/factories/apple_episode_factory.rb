FactoryBot.define do
  factory :apple_episode, class: Apple::Episode do
    show { build(:apple_show) }
    api { build(:apple_api) }

    # set up transient api_response
    transient do
      feeder_episode { create(:episode) }
      api_response { build(:apple_episode_api_response, item_guid: feeder_episode.item_guid) }
      apple_hosted_audio_asset_container_id { "456" }
    end

    # set a complete episode factory varient
    factory :uploaded_apple_episode do
      feeder_episode { create(:episode) }
      transient do
        apple_hosted_audio_asset_container_id { "456" }
        api_response do
          build(:apple_episode_api_response,
            publishing_state: "PUBLISH",
            item_guid: feeder_episode.item_guid,
            apple_hosted_audio_asset_container_id: apple_hosted_audio_asset_container_id,
            apple_hosted_audio_state: Apple::Episode::AUDIO_ASSET_SUCCESS)
        end
      end
      after(:build) do |apple_episode, evaluator|
        container = create(:apple_podcast_container, episode: apple_episode.feeder_episode)
        delivery = create(:apple_podcast_delivery, episode: apple_episode.feeder_episode, podcast_container: container)
        _delivery_file = create(:apple_podcast_delivery_file,
          delivery: delivery,
          episode: apple_episode.feeder_episode,
          api_marked_as_uploaded: true,
          upload_operations_complete: true)

        feeder_episode = apple_episode.feeder_episode

        # The content model calls Episode#publish!
        # and that triggers a call to Episode#apple_mark_for_reupload!
        # This modifies state to indicate that the episode needs to be reuploaded
        create(:content, episode: feeder_episode, position: 1, status: "complete")
        create(:content, episode: feeder_episode, position: 2, status: "complete")
        v1 = feeder_episode.cut_media_version!

        # Now model the case where the episode is uploaded.
        # First we've gathered file metadata from the CDN
        feeder_episode.apple_update_delivery_status(source_size: 1.megabyte,
          source_url: "https://cdn.example.com/episode.mp3",
          source_media_version_id: v1.id)

        # Then we've delivered (and necessarily uploaded)
        feeder_episode.apple_mark_as_delivered!
      end
    end

    after(:build) do |apple_episode, evaluator|
      api_response = evaluator.api_response
      external_id = api_response["api_response"]["api_response"]["val"]["data"]["id"]
      apple_episode.feeder_episode.create_apple_sync_log!(external_id: external_id, **api_response) unless apple_episode.feeder_episode.apple_sync_log.present?
    end

    initialize_with { new(show: show, feeder_episode: feeder_episode, api: api) }
  end
end
