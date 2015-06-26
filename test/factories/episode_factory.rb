FactoryGirl.define do
  factory :episode do
    podcast
    sequence(:prx_uri) { |n| "/api/v1/stories/#{(87683 + n)}" }

    sequence(:guid) { |n| "prx:#{87683 + n}:#{SecureRandom.uuid}" }

    sequence(:overrides) do |n|
      {
        title: "Episode #{n}",
        pub_date: "Fri, 09 Jan 2015 12:49:44 EST"
      }
    end
  end
end
