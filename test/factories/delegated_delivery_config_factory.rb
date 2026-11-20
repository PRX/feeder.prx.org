FactoryBot.define do
  factory :delegated_delivery_config, class: Apple::DelegatedDeliveryConfig do
    publish_enabled { true }
    sync_blocks_rss { true }
    feed { association(:feed, podcast: association(:podcast, :with_apple_key)) }

    transient do
      # The bound Apple show; defaults to the binding factory's sequence.
      apple_show_id { nil }
    end

    after(:build) do |config, evaluator|
      config.show_feed_binding ||= build(:apple_show_feed_binding,
        {feed: config.feed.podcast.public_feed, apple_show_id: evaluator.apple_show_id}.compact)
    end
  end
end
