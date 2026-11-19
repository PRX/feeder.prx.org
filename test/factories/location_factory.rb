FactoryBot.define do
  factory :location do
    association :owner, factory: :podcast
    name { "Austin" }
    rel { "creator" }
    latitude { 30.2711286 }
    longitude { -97.7436995 }
    osm { "R113314" }
    country { "US" }
  end
end
