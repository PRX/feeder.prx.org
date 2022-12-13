FactoryBot.define do
  factory :apple_episode, class: Apple::Episode do
    show { build(:apple_show) }
    api { build(:apple_api) }
  end
end
