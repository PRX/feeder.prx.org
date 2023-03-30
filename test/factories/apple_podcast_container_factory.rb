FactoryBot.define do
  factory :apple_podcast_container, class: Apple::PodcastContainer do
    episode
    sequence(:vendor_id) { |n| n.to_s }
    sequence(:apple_episode_id) { |n| n.to_s }
  end
end
