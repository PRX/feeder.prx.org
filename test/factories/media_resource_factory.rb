FactoryBot.define do
  factory :media_resource do
    association :episode, factory: :episode, prx_uri: "/api/v1/stories/80548"
    sequence(:guid) { |n| "ca047dce-9df5-4132-a04b-31d24c7c55a#{n}" }

    mime_type { "audio/mpeg" }
    file_size { 774059 }
    medium { "audio" }
    sample_rate { 44100 }
    channels { 2 }
    duration { 48 }
    bit_rate { 64 }
    original_url { "s3://prx-testing/test/audio.mp3" }
    status { "created" }

    transient do
      task_count { 1 }
    end

    after(:create) do |media_resource, evaluator|
      create_list(:copy_media_task, evaluator.task_count, owner: media_resource)
    end

    factory :content, class: Content do
      position { 1 }
      task_count { 0 }
    end

    factory :uncut, class: Uncut do
      segmentation { [1.23, 4.56] }
      task_count { 0 }
    end
  end
end
