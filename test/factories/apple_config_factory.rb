FactoryBot.define do
  factory :apple_config, class: Apple::DelegatedDeliveryConfig do
    publish_enabled { true }
    sync_blocks_rss { true }
    key { build(:apple_key) }
    feed

    trait :with_show_feed_binding do
      after(:build) do |config|
        show_id = config.feed.apple_show_id.presence || "show-#{SecureRandom.uuid}"
        config.feed.apple_show_id ||= show_id
        config.show_feed_binding = build(
          :apple_show_feed_binding,
          feed: config.legacy_public_feed || build(:public_feed),
          apple_key: config.key,
          apple_show_id: show_id
        )
      end
    end
  end
end
