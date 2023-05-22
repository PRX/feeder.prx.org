FactoryBot.define do
  factory :episode_image do
    sequence(:guid) { |n| "4e745a8c-77ee-481c-a72b-fd868dfd1c9#{n}" }
    original_url { "test/fixtures/image.png" }
    alt_text { "valid episode image" }
    caption { "just look at those things" }
    credit { "feeder" }
    width { 1400 }
    height { 1400 }
    size { 14467 }
    format { "png" }
    status { "complete" }

    factory :episode_image_with_episode, class: EpisodeImage do
      episode
    end
  end
end
