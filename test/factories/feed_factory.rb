FactoryBot.define do
  factory :feed do
    sequence(:slug) { |n| "myfeed#{n}" }

    file_name { "feed-rss.xml" }
    audio_format { Hash(f: "flac", b: 16, c: 2, s: 44100) }

    title { "new feed" }
    subtitle { "Goofy laughsters" }
    description { "A goofy fun-time laughcast with doofuses" }

    url { "http://feeds.feedburner.com/thornmorris" }
    new_feed_url { "http://feeds.feedburner.com/newthornmorris" }
    enclosure_template { Feed.enclosure_template_default }
    enclosure_prefix { "" }

    factory :default_feed do
      slug { nil }
      file_name { "feed-rss.xml" }
      private { false }
      audio_format { Hash(f: "mp3", b: 128, c: 2, s: 44100) }
      enclosure_template { "http://www.podtrac.com/pts/redirect{extension}/media.blubrry.com/transistor/{host}{+path}" }
      enclosure_prefix { "" }
      include_podcast_value { true }
      include_donation_url { true }

      after(:build) do |feed, _evaluator|
        feed.feed_image = build(:feed_image)
        feed.itunes_image = build(:itunes_image)

        feed.feed_image.tasks.build
        feed.itunes_image.tasks.build

        feed.itunes_categories = [build(:itunes_category)]
      end
    end

    factory :private_feed do
      private { true }
      tokens { [FeedToken.new(label: "my-tok")] }
    end

    factory :public_feed do
      private { false }
    end

    factory :apple_feed, class: "Feeds::AppleSubscription" do
      type { "Feeds::AppleSubscription" }
      private { true }
      tokens { [FeedToken.new(label: "apple-private")] }

      after(:build) do |feed, _evaluator|
        feed.apple_config = build(:apple_config)
      end
    end

    factory :megaphone_feed, class: "Feeds::MegaphoneFeed" do
      type { "Feeds::MegaphoneFeed" }
      private { true }

      after(:build) do |feed, _evaluator|
        feed.megaphone_config = build(:megaphone_config, feed: feed)
      end
    end
  end
end
