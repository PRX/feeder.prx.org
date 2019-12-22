FactoryGirl.define do
  factory :feed do
    podcast
    sequence(:name) { |n| "test-#{n}" }
  end
end
