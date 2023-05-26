FactoryBot.define do
  factory :apple_podcast_delivery, class: Apple::PodcastDelivery do
    episode
    sequence(:external_id) { |n| "vendor_id_#{n}" }
  end
end
