FactoryBot.define do
  factory :itunes_category do
    feed
    name { "Leisure" }
    subcategories { ["Aviation", "Automotive"] }
  end
end
