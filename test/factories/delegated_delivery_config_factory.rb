FactoryBot.define do
  factory :delegated_delivery_config, class: Apple::DelegatedDeliveryConfig do
    publish_enabled { true }
    sync_blocks_rss { true }
    feed

    transient do
      # The podcast's Apple key; defaults to the podcast's existing key or a new one.
      key { nil }
      # The bound Apple show; defaults to the binding factory's sequence.
      apple_show_id { nil }
    end

    after(:build) do |config, evaluator|
      podcast = config.feed.podcast || build(:podcast)
      config.feed.podcast = podcast

      apple_key = evaluator.key || podcast.apple_key || build(:apple_key)
      apple_key.account_id = podcast.account_id || apple_key.account_id
      podcast.apple_key = apple_key

      config.show_feed_binding ||= build(:apple_show_feed_binding,
        {feed: podcast.public_feed, apple_show_id: evaluator.apple_show_id}.compact)
    end

    after(:create) do |config|
      podcast = config.feed.podcast
      podcast.save! if podcast.changed? || podcast.apple_key&.new_record?
    end
  end
end
