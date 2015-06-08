FactoryGirl.define do
  factory :episode do
    podcast
    sequence(:prx_id) { |n| (87683 + n) }

    guid "prx:#{87683}:#{SecureRandom.uuid}"

    sequence(:overrides) do |n|
      {
        title: "Episode #{n}",
        pub_date: "Fri, 09 Jan 2015 12:49:44 EST"
      }
    end
  end
end
