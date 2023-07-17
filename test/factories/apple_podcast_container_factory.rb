FactoryBot.define do
  factory :apple_podcast_container, class: Apple::PodcastContainer do
    episode
    sequence(:vendor_id) { |n| n.to_s }
    sequence(:apple_episode_id) { |n| n.to_s }

    transient do
      sequence(:external_id) { |n| "apple_container_id_#{n}" }
    end

    after(:build) do |podcast_container, evaluator|
      api_response = build(:podcast_container_api_response, podcast_container_id: evaluator.external_id)
      podcast_container.apple_sync_log = SyncLog.new(external_id: evaluator.external_id, feeder_type: :podcast_containers, **api_response)
    end
  end
end
