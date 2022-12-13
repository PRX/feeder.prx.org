FactoryBot.define do
  factory :episode_image do
    sequence(:guid) { |n| "4e745a8c-77ee-481c-a72b-fd868dfd1c9#{n}" }
    original_url { 'test/fixtures/image.png' }
    link { 'http://www.maximumfun.org/shows/jordan-jesse-go' }
    title { 'Jordan, Jesse GO!' }
    description { 'Not a picture of Jordan or Jesse' }
    width { 144 }
    height { 144 }
    size { 14467 }
    format { 'png' }
    status { 'complete' }

    after(:create) do |episode_image, _evaluator|
      episode_image.url = episode_image.published_url if episode_image.status == 'complete'
    end

    factory :episode_image_with_episode, class: EpisodeImage do
      episode
    end
  end
end
