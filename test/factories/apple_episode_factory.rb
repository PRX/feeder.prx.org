FactoryBot.define do
  factory :apple_episode, class: Apple::Episode do
    show { build(:apple_show) }
    api { build(:apple_api) }

    # set up transient api_response
    transient do
      feeder_episode { create(:episode) }
      api_response { build(:apple_episode_api_response) }
    end

    # set a complete episode factory varient
    factory :uploaded_apple_episode do
      feeder_episode do
        ep = create(:episode)
        ep.apple_mark_as_delivered!
        ep
      end
      transient do
        api_response do
          build(:apple_episode_api_response,
            publishing_state: "PUBLISH",
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

        create(:content, episode: apple_episode.feeder_episode, position: 1, status: "complete")
        create(:content, episode: apple_episode.feeder_episode, position: 2, status: "complete")
        v1 = apple_episode.feeder_episode.cut_media_version!

        apple_episode.delivery_status.update!(delivered: true, source_media_version_id: v1.id)
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
