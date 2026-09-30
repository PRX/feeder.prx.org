require "test_helper"

describe Apple::FeedSettings do
  let(:podcast) { create(:podcast) }
  let(:key) { create(:apple_key, account_id: podcast.account_id) }
  let(:binding) { create(:apple_show_feed_binding, feed: podcast.default_feed, apple_show_id: "show-1") }

  before do
    podcast.update!(apple_key: key)
  end

  def stub_show(id, status: 200)
    stub_request(:get, "https://aardvark.prx.org/shows/#{id}").to_return(status: status, body: {data: {id: id, type: "shows"}}.to_json)
  end

  describe "saving with the feed" do
    it "rolls back feed edits when a requested connection is inaccessible" do
      public_feed = binding.feed
      original_title = public_feed.title
      public_feed.title = "Changed"
      stub_show("missing", status: 404)
      refute public_feed.update(apple_settings: {connection: "missing"})
      assert_predicate public_feed.apple_settings.errors[:connection], :present?
      assert_equal original_title, public_feed.reload.title
      assert_equal "show-1", binding.reload.apple_show_id
    end

    it "reads the requested show before the feed row is written" do
      public_feed = binding.feed
      public_feed.title = "Changed"
      stub_request(:get, "https://aardvark.prx.org/shows/show-2").to_return do
        refute_equal "Changed", Feed.where(id: public_feed.id).pick(:title)
        {status: 200, body: {data: {id: "show-2", type: "shows"}}.to_json}
      end

      assert public_feed.update(apple_settings: {connection: "show-2"})
      assert_equal "show-2", binding.reload.apple_show_id
    end

    it "does not read the requested show when the feed is invalid" do
      public_feed = binding.feed
      public_feed.file_name = ""

      refute public_feed.update(apple_settings: {connection: "show-2"})
      assert_not_requested :get, "https://aardvark.prx.org/shows/show-2"
      assert_equal "show-1", binding.reload.apple_show_id
    end

    it "reconnects a feed after removing its connection on the same feed instance" do
      public_feed = create(:public_feed, podcast: podcast)
      stub_show("show-1")
      stub_show("show-2")

      assert public_feed.update(apple_settings: {connection: "show-1"})
      assert public_feed.update(apple_settings: {connection: ""})
      assert public_feed.update(apple_settings: {connection: "show-2"})

      assert_equal "show-2", public_feed.reload.apple_show_feed_binding.apple_show_id
    end

    it "saves ordinary metadata without verifying the unchanged Apple connection" do
      public_feed = binding.feed
      public_feed.title = "Changed"

      assert public_feed.update(apple_settings: {connection: "show-1"})
      assert_equal "Changed", public_feed.reload.title
      assert_not_requested :get, "https://aardvark.prx.org/shows/show-1"
    end

    it "keeps saved settings that were not submitted" do
      delivery_feed = create(:private_feed, podcast: podcast)
      config = create(:delegated_delivery_config, feed: delivery_feed, show_feed_binding: binding, publish_enabled: true)

      assert delivery_feed.update(apple_settings: {})
      assert_equal binding, config.reload.show_feed_binding
      assert_predicate config, :publish_enabled?
    end

    it "drops unsaved settings when the feed reloads" do
      delivery_feed = create(:private_feed, podcast: podcast)
      create(:delegated_delivery_config, feed: delivery_feed, show_feed_binding: binding)
      delivery_feed.file_name = ""

      refute delivery_feed.update(apple_settings: {delivery: ""})
      delivery_feed.reload

      assert_equal binding.id.to_s, delivery_feed.apple_settings.delivery
      assert delivery_feed.save
      assert_predicate delivery_feed.reload.delegated_delivery_config, :present?
    end
  end

  describe "saved values" do
    let(:delivery_feed) { create(:private_feed, podcast: podcast) }

    it "reads the delivery from the saved config's binding" do
      assert_equal "", Apple::FeedSettings.new(delivery_feed).delivery

      create(:delegated_delivery_config, feed: delivery_feed, show_feed_binding: binding)
      settings = Apple::FeedSettings.new(delivery_feed.reload)
      assert_equal binding.id.to_s, settings.delivery
      assert_equal "mapped", settings.route
      assert_equal binding, settings.mapped_binding
    end

    it "treats a private feed's connection without a config as delivering to its own show" do
      create(:apple_show_feed_binding, feed: delivery_feed, apple_show_id: "show-9")

      settings = Apple::FeedSettings.new(delivery_feed.reload)
      assert_equal Apple::FeedSettings::OWN, settings.delivery
      assert_equal "own", settings.route
    end

    it "reports only submitted values as changed" do
      settings = Apple::FeedSettings.new(binding.feed, connection: "show-1", publish_enabled: "1")

      refute settings.connection_changed?
      assert settings.publish_enabled_changed?
      refute settings.delivery_changed?
    end
  end

  describe "#mapped_binding" do
    it "ignores a binding from another podcast" do
      other_binding = create(:apple_show_feed_binding, apple_show_id: "other-show")
      delivery_feed = create(:private_feed, podcast: podcast)

      assert_nil Apple::FeedSettings.new(delivery_feed, delivery: other_binding.id).mapped_binding
    end

    it "ignores a private feed's binding" do
      private_binding = create(:apple_show_feed_binding, feed: create(:private_feed, podcast: podcast), apple_show_id: "private-show")
      delivery_feed = create(:private_feed, podcast: podcast)

      assert_nil Apple::FeedSettings.new(delivery_feed, delivery: private_binding.id).mapped_binding
    end

    it "ignores a binding another feed delivers through" do
      create(:delegated_delivery_config, feed: create(:private_feed, podcast: podcast), show_feed_binding: binding)
      delivery_feed = create(:private_feed, podcast: podcast)

      assert_nil Apple::FeedSettings.new(delivery_feed, delivery: binding.id).mapped_binding
    end

    it "keeps the saved mapping when its feed is no longer available" do
      delivery_feed = create(:private_feed, podcast: podcast)
      create(:delegated_delivery_config, feed: delivery_feed, show_feed_binding: binding)
      binding.feed.update_column(:private, true)

      settings = Apple::FeedSettings.new(delivery_feed.reload, delivery: binding.id)
      assert_equal binding, settings.mapped_binding
      assert_includes settings.mappable_bindings, binding
    end
  end
end
