FactoryGirl.define do
  factory :media_resource do
    association :episode, factory: :episode, prx_uri: '/api/v1/stories/80548'
    sequence(:guid) { |n| "ca047dce-9df5-4132-a04b-31d24c7c55a#{n}" }

    mime_type 'audio/mpeg'
    file_size 774059
    medium 'audio'
    sample_rate 44100
    channels 2
    duration 48
    bit_rate 64

    after(:create) do |media_resource, evaluator|
      create_list(:copy_media_task, 1, owner: media_resource)
    end

    factory :enclosure, class: Enclosure do
    end

    factory :content, class: Content do
    end
  end
end
