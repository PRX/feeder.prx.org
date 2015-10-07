FactoryGirl.define do
  factory :itunes_category do
    podcast
    name 'Games & Hobbies'
    subcategories ['Aviation', 'Automotive']
  end
end
