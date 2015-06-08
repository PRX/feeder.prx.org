FactoryGirl.define do
  factory :episode do
    podcast
    prx_id 87683

    sequence(:overrides) do |n|
      {
        title: "Episode #{n}",
        pub_date: "Fri, 09 Jan 2015 12:49:44 EST"
      }
    end
  end
end
