FactoryBot.define do
  factory :itunes_category do
    podcast
    name { 'Leisure' }
    subcategories { ['Aviation', 'Automotive'] }
  end
end
