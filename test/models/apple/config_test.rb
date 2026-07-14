require "test_helper"

describe Apple::DelegatedDeliveryConfig do
  describe "#valid?" do
    it "is unique to a podcast" do
      podcast = create(:podcast)
      f1 = create(:feed, podcast: podcast)
      c1 = create(:apple_config, feed: f1)
      assert c1.valid?

      f2 = create(:feed, podcast: podcast)
      c2 = build(:apple_config, feed: f2)
      refute c2.valid?
      assert_equal ["podcast already has an apple config"], c2.errors[:feed]

      # can't have 2 on same feed either
      c3 = build(:apple_config, feed: f1)
      refute c3.valid?
      assert_equal ["podcast already has an apple config"], c2.errors[:feed]
    end

    it "cannot be the default feed" do
      podcast = create(:podcast)
      c1 = build(:apple_config, feed: podcast.default_feed)
      refute c1.valid?
      assert_equal ["must differ from the public feed"], c1.errors[:feed]
    end

    it "cannot be the bound public feed" do
      podcast = create(:podcast)
      public_feed = create(:public_feed, podcast: podcast)
      binding = build(:apple_show_feed_binding, feed: public_feed)
      config = build(:apple_config, feed: public_feed, show_feed_binding: binding)

      refute config.valid?
      assert_equal ["must differ from the public feed"], config.errors[:feed]
    end
  end

  it "delegates associations" do
    podcast = build_stubbed(:podcast)
    public_feed = podcast.default_feed
    private_feed = build_stubbed(:private_feed, podcast: podcast)
    config = build_stubbed(:apple_config, feed: private_feed)

    assert_equal podcast, config.podcast
    assert_equal podcast.id, config.podcast_id
    assert_equal podcast.title, config.podcast_title
    assert_equal public_feed, config.legacy_public_feed
    assert_equal private_feed, config.private_feed
  end

  describe "Apple routing" do
    it "uses legacy routing by default" do
      config, legacy, _binding = build_routing_config

      with_apple_routing_source(nil) do
        assert_equal :legacy, config.routing_source
        assert_equal legacy[:key], config.routing_key
        assert_equal legacy[:public_feed], config.public_feed
        assert_equal legacy[:show_id], config.apple_show_id
        assert_equal legacy[:delivery_feed], config.delivery_feed

        publisher = config.build_publisher
        assert_equal legacy[:key].key_id, publisher.api.key_id
        assert_equal legacy[:public_feed], publisher.public_feed
        assert_equal legacy[:delivery_feed], publisher.private_feed
        assert_equal legacy[:show_id], publisher.show.apple_id
      end
    end

    it "uses show-feed-binding routing when selected" do
      config, legacy, binding = build_routing_config

      with_apple_routing_source("show_feed_binding") do
        assert_equal :show_feed_binding, config.routing_source
        assert_equal binding.apple_key, config.routing_key
        assert_equal binding.feed, config.public_feed
        assert_equal binding.apple_show_id, config.apple_show_id
        assert_equal legacy[:delivery_feed], config.delivery_feed

        publisher = config.build_publisher
        assert_equal binding.apple_key.key_id, publisher.api.key_id
        assert_equal binding.feed, publisher.public_feed
        assert_equal legacy[:delivery_feed], publisher.private_feed
        assert_equal binding.apple_show_id, publisher.show.apple_id
      end
    end

    it "rejects an unsupported routing source" do
      config = build(:apple_config)

      error = assert_raises(ArgumentError) do
        with_apple_routing_source("surprise") { config.routing_source }
      end

      assert_match(/Unsupported APPLE_ROUTING_SOURCE="surprise"/, error.message)
    end
  end

  def build_routing_config
    podcast = create(:podcast)
    public_feed = podcast.public_feed
    delivery_feed = create(:private_feed, podcast: podcast, apple_show_id: "legacy-feed-show")
    legacy_key = create(:apple_key)
    binding_key = create(:apple_key)
    binding_feed = create(:public_feed, podcast: podcast)
    binding = create(
      :apple_show_feed_binding,
      feed: binding_feed,
      apple_key: binding_key,
      apple_show_id: "binding-show"
    )
    config = create(
      :apple_config,
      feed: delivery_feed,
      key: legacy_key,
      show_feed_binding: binding
    )
    SyncLog.log!(
      integration: :apple,
      feeder_type: :feeds,
      feeder_id: public_feed.id,
      external_id: "legacy-sync-show"
    )

    legacy = {
      key: legacy_key,
      public_feed: public_feed,
      delivery_feed: delivery_feed,
      show_id: "legacy-sync-show"
    }

    [config, legacy, binding]
  end

  def with_apple_routing_source(source)
    previous = ENV["APPLE_ROUTING_SOURCE"]
    source ? ENV["APPLE_ROUTING_SOURCE"] = source : ENV.delete("APPLE_ROUTING_SOURCE")
    yield
  ensure
    previous ? ENV["APPLE_ROUTING_SOURCE"] = previous : ENV.delete("APPLE_ROUTING_SOURCE")
  end
end
