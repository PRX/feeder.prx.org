FactoryBot.define do
  factory :apple_episode, class: Apple::Episode do
    episode { build(:episode, apple_sync_log: SyncLog.new(feeder_type: :episodes, external_id: "123")) }
    show { build(:apple_show) }
    api { build(:apple_api) }

    initialize_with { new(show: show, feeder_episode: episode, api: api) }
  end
end
