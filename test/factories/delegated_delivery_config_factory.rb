FactoryBot.define do
  factory :delegated_delivery_config, class: Apple::DelegatedDeliveryConfig do
    publish_enabled { true }
    sync_blocks_rss { true }
    key { build(:apple_key) }
    feed

    trait :with_show_feed_binding do
      after(:build) do |config|
        show_id = config.feed.apple_show_id.presence || "show-#{SecureRandom.uuid}"
        config.feed.apple_show_id ||= show_id
        podcast = config.feed.podcast || build(:podcast)
        config.feed.podcast = podcast
        podcast.apple_key = config.key
        config.show_feed_binding = build(
          :apple_show_feed_binding,
          feed: podcast.public_feed,
          apple_show_id: show_id
        )
      end

      after(:create) do |config|
        config.podcast.update!(apple_key: config.key) unless config.podcast.apple_key_id == config.key_id
      end
    end
  end
end
