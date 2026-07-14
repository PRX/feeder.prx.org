FactoryBot.define do
  factory :apple_config, class: Apple::DelegatedDeliveryConfig do
    publish_enabled { true }
    sync_blocks_rss { true }
    key { build(:apple_key) }
    feed
  end
end
