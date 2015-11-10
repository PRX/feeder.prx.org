FactoryGirl.define do
  factory :media_resource do
    association :episode, factory: :episode, prx_uri: '/api/v1/stories/80548'
    sequence(:guid) { |n| "ca047dce-9df5-4132-a04b-31d24c7c55a#{n}" }

    after(:create) do |media_resource, evaluator|
      create_list(:copy_audio_task, 1, owner: media_resource)
    end

    factory :enclosure, class: Enclosure do
    end

    factory :content do
    end
  end
end
