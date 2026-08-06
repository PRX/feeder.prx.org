require "test_helper"

describe "feed-scoped Apple delegated delivery" do
  let(:podcast) { create(:podcast) }
  let(:delivery_feed) { create(:private_feed, podcast: podcast, label: "Members") }
  let(:key) { create(:apple_key, account_id: podcast.account_id) }
  let(:binding) { create(:apple_show_feed_binding, feed: podcast.default_feed, apple_show_id: "show-1") }

  before do
    podcast.update!(apple_key: key)
  end

  it "attaches delegated delivery to a normal feed" do
    config = create(:delegated_delivery_config, feed: delivery_feed, show_feed_binding: binding)

    assert_nil delivery_feed.type
    assert_equal config, delivery_feed.reload.delegated_delivery_config
    assert_equal :apple, delivery_feed.integration_type
    assert_equal "Members", delivery_feed.label
  end

  it "publishes through the feed-scoped config" do
    create(:delegated_delivery_config, feed: delivery_feed, show_feed_binding: binding, publish_enabled: true)

    assert delivery_feed.reload.publish_to_apple?
    assert delivery_feed.publish_integration?
  end

  it "does not publish when delegated delivery is disabled" do
    create(:delegated_delivery_config, feed: delivery_feed, show_feed_binding: binding, publish_enabled: false)

    refute delivery_feed.reload.publish_to_apple?
    refute delivery_feed.publish_integration?
  end

  it "allows a public feed to delegate through its own binding" do
    public_feed = create(:public_feed, podcast: podcast)
    own_binding = create(:apple_show_feed_binding, feed: public_feed, apple_show_id: "show-2")

    config = create(:delegated_delivery_config, feed: public_feed, show_feed_binding: own_binding)

    assert_equal public_feed, config.feed
    assert_equal own_binding, config.show_feed_binding
  end

  it "removes delegated delivery without removing the feed" do
    create(:delegated_delivery_config, feed: delivery_feed, show_feed_binding: binding)
    original_count = Apple::DelegatedDeliveryConfig.count

    delivery_feed.update!(delegated_delivery_config_attributes: {id: delivery_feed.delegated_delivery_config.id, _destroy: "1"})

    assert_equal original_count - 1, Apple::DelegatedDeliveryConfig.count
    assert_predicate delivery_feed.reload, :persisted?
    assert_nil delivery_feed.delegated_delivery_config
  end
end
