FactoryGirl.define do
  factory :episode do
    podcast
    association :image, factory: :image
    prx_id 87683

    sequence(:overrides) do |n|
      {
        title: "Episode #{n}",
        pub_date: "Fri, 09 Jan 2015 12:49:44 EST"
      }.to_json
    end
  end
end
