require "test_helper"

describe Apple::DelegatedDeliveryConfig do
  describe "#valid?" do
    it "rejects clearing an existing binding" do
      config = create(:delegated_delivery_config)
      binding = config.show_feed_binding

      refute config.update(show_feed_binding: nil)
      assert config.errors.of_kind?(:show_feed_binding, :blank)
      assert_equal binding, config.reload.show_feed_binding
    end

    it "allows only one config per show feed binding" do
      podcast = create(:podcast)
      binding = create(:apple_show_feed_binding, feed: create(:public_feed, podcast: podcast))
      key = create(:apple_key, account_id: podcast.account_id)
      create(
        :delegated_delivery_config,
        feed: create(:private_feed, podcast: podcast),
        key: key,
        show_feed_binding: binding
      )
      config = build(
        :delegated_delivery_config,
        feed: create(:private_feed, podcast: podcast),
        key: key,
        show_feed_binding: binding
      )

      refute config.valid?
      assert_equal ["has already been taken"], config.errors[:show_feed_binding_id]
    end

    it "allows only one config per configured feed" do
      podcast = create(:podcast)
      first_binding = create(:apple_show_feed_binding, feed: podcast.default_feed)
      second_binding = create(:apple_show_feed_binding, feed: create(:public_feed, podcast: podcast))
      delivery_feed = create(:private_feed, podcast: podcast)
      create(:delegated_delivery_config, feed: delivery_feed, show_feed_binding: first_binding)

      duplicate = build(:delegated_delivery_config, feed: delivery_feed, show_feed_binding: second_binding)

      refute duplicate.valid?
      assert_equal ["has already been taken"], duplicate.errors[:feed_id]
    end

    it "requires the binding and configured feed to belong to the same podcast" do
      delivery_feed = create(:private_feed, podcast: create(:podcast))
      other_binding = create(:apple_show_feed_binding, feed: create(:podcast).default_feed)

      config = build(:delegated_delivery_config, feed: delivery_feed, show_feed_binding: other_binding)

      refute config.valid?
      assert_equal ["must belong to the configured feed's podcast"], config.errors[:show_feed_binding]
    end

    it "allows a private feed to deliver through its own binding" do
      delivery_feed = create(:private_feed, podcast: create(:podcast))
      own_binding = create(:apple_show_feed_binding, feed: delivery_feed)

      assert build(:delegated_delivery_config, feed: delivery_feed, show_feed_binding: own_binding).valid?
    end

    it "rejects another private feed's binding" do
      podcast = create(:podcast)
      other_binding = create(:apple_show_feed_binding, feed: create(:private_feed, podcast: podcast))

      config = build(:delegated_delivery_config, feed: create(:private_feed, podcast: podcast), show_feed_binding: other_binding)

      refute config.valid?
      assert_equal ["must belong to a public feed or this feed"], config.errors[:show_feed_binding]
    end
  end

  it "delegates associations" do
    podcast = build_stubbed(:podcast)
    private_feed = build_stubbed(:private_feed, podcast: podcast)
    config = build_stubbed(:delegated_delivery_config, feed: private_feed)

    assert_equal private_feed, config.private_feed
  end

  it "routes through the show feed binding" do
    podcast = create(:podcast)
    apple_key = create(:apple_key, account_id: podcast.account_id)
    podcast.update!(apple_key: apple_key)
    binding = create(:apple_show_feed_binding, feed: create(:public_feed, podcast: podcast), apple_show_id: "binding-show")
    config = create(:delegated_delivery_config, feed: create(:private_feed, podcast: podcast), show_feed_binding: binding)

    assert_equal apple_key, config.apple_key
    assert_equal binding.feed, config.public_feed
    assert_equal binding.apple_show_id, config.apple_show_id

    publisher = config.build_publisher
    assert_equal apple_key.key_id, publisher.api.key_id
    assert_equal binding.feed, publisher.public_feed
    assert_equal config.private_feed, publisher.private_feed
    assert_equal binding.apple_show_id, publisher.show.apple_id
  end
end
