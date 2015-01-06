FactoryGirl.define do
  factory :episode do
    podcast
    association :image, factory: :image
    prx_id 87683
    sequence(:overrides) {|n| "{\"title\":\"Episode #{n}\"}" }
  end
end
