FactoryBot.define do
  factory :apple_episode, class: Apple::Episode do
    episode { build(:episode) }
    show { build(:apple_show) }
    api { build(:apple_api) }

    initialize_with { new(show: show, feeder_episode: episode, api: api) }
  end
end
