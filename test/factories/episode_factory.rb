FactoryGirl.define do
  factory :episode do
    podcast
    sequence(:prx_uri) { |n| "/api/v1/stories/#{(87683 + n)}" }

    sequence(:guid) { |n| "ba047dce-9df5-4132-a04b-31d24c7c55a#{n}" }

    sequence(:overrides) do |n|
      {
        title: "Episode #{n}",
        pub_date: "Fri, 09 Jan 2015 12:49:44 EST"
      }
    end

    after(:create) do |episode, evaluator|
      create_list(:copy_audio_task, 1, owner: episode)
    end
  end
end
