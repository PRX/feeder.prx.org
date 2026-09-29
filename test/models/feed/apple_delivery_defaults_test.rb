require "test_helper"

describe Feed, "Apple delivery defaults" do
  let(:default_feed) { build(:default_feed, display_episodes_count: 99, audio_format: nil) }
  let(:podcast) { create(:podcast, default_feed: default_feed) }
  let(:new_feed) { podcast.feeds.new(private: false, slug: "") }

  it "sets the Apple Subscriptions defaults" do
    new_feed.assign_apple_delivery_defaults

    assert_equal FeedApple::APPLE_DELIVERY_SLUG, new_feed.slug
    assert_equal Apple::DelegatedDeliveryConfig::DEFAULT_TOKEN_LABEL, new_feed[:label]
    assert_equal FeedApple::APPLE_DELIVERY_AUDIO_FORMAT.stringify_keys, new_feed.audio_format.to_h
    assert_equal 99, new_feed.display_episodes_count
    assert_equal FeedApple::APPLE_DELIVERY_ZONES, new_feed.include_zones
    assert_predicate new_feed, :private?
  end

  it "picks a free slug when the Apple Subscriptions slug is taken" do
    create(:feed, podcast: podcast, slug: FeedApple::APPLE_DELIVERY_SLUG)
    create(:feed, podcast: podcast, slug: "#{FeedApple::APPLE_DELIVERY_SLUG}-2")

    new_feed.assign_apple_delivery_defaults

    assert_equal "#{FeedApple::APPLE_DELIVERY_SLUG}-3", new_feed.slug
  end

  it "keeps values already set, other than privacy" do
    new_feed.assign_attributes(slug: "foo", label: "Members", audio_format: {f: "flac"}, display_episodes_count: 88, include_zones: ["ad"])

    new_feed.assign_apple_delivery_defaults

    assert_equal "foo", new_feed.slug
    assert_equal "Members", new_feed[:label]
    assert_equal "flac", new_feed.audio_format[:f]
    assert_equal 88, new_feed.display_episodes_count
    assert_equal ["ad"], new_feed.include_zones
    assert_predicate new_feed, :private?
  end

  it "uses the default feed's mp3 format, raised to Apple's minimums" do
    default_feed.update!(audio_format: {f: "mp3", b: 192, c: 1, s: 22050})

    new_feed.assign_apple_delivery_defaults

    assert_equal({"f" => "mp3", "b" => 192, "c" => 1, "s" => 44100}, new_feed.audio_format.to_h)
  end

  it "uses the max published episode mp3 format" do
    c1 = build(:content, mime_type: "audio/mpeg", bit_rate: 192, channels: 1, sample_rate: 22050)
    c2 = build(:content, mime_type: "audio/mpeg", bit_rate: 64, channels: 2, sample_rate: 44100)
    c3 = build(:content, mime_type: "audio/wav", bit_rate: 16, channels: 1, sample_rate: 48000)
    create(:episode, podcast: podcast, contents: [c1])
    create(:episode, podcast: podcast, contents: [c2])
    create(:episode, podcast: podcast, contents: [c3])

    new_feed.assign_apple_delivery_defaults

    assert_equal({"f" => "mp3", "b" => 192, "c" => 2, "s" => 44100}, new_feed.audio_format.to_h)
  end
end
