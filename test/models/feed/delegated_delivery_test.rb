require "test_helper"

describe Feed, "Apple delegated delivery" do
  let(:podcast) { create(:podcast) }
  let(:delivery_feed) { create(:private_feed, podcast: podcast, label: "Members") }
  let(:key) { create(:apple_key, account_id: podcast.account_id) }
  let(:binding) { create(:apple_show_feed_binding, feed: podcast.default_feed, apple_show_id: "show-1") }
  let(:apple_feed) { build(:apple_feed, podcast: podcast) }

  before do
    podcast.update!(apple_key: key)
  end

  it "rolls back feed edits when a requested connection is inaccessible" do
    public_feed = binding.feed
    original_title = public_feed.title
    public_feed.assign_attributes(title: "Changed", apple_connection: "missing")
    stub_request(:get, "https://aardvark.prx.org/shows/missing").to_return(status: 404, body: "{}")

    refute public_feed.save_with_apple_connection
    assert_predicate public_feed.errors[:apple_connection], :present?
    assert_equal original_title, public_feed.reload.title
    assert_equal "show-1", binding.reload.apple_show_id
  end

  it "saves ordinary metadata without verifying the unchanged Apple connection" do
    public_feed = binding.feed
    public_feed.title = "Changed"

    assert public_feed.save_with_apple_connection
    assert_equal "Changed", public_feed.reload.title
    assert_not_requested :get, "https://aardvark.prx.org/shows/show-1"
  end

  it "attaches delegated delivery to a normal feed" do
    config = create(:delegated_delivery_config, feed: delivery_feed, show_feed_binding: binding)

    assert_nil delivery_feed.type
    assert_equal config, delivery_feed.reload.delegated_delivery_config
    assert_equal [:apple], delivery_feed.integration_types
    assert_equal "Members", delivery_feed.label
  end

  it "requires connected feeds to stay public even without delegated delivery" do
    public_feed = binding.feed

    refute public_feed.update(private: true)
    assert_includes public_feed.errors[:private], "cannot be enabled while connected to an Apple show"
    refute public_feed.reload.private?
    assert_equal binding, public_feed.apple_show_feed_binding
  end

  it "allows a disconnected feed to become private" do
    public_feed = create(:public_feed, podcast: podcast)
    connection = create(:apple_show_feed_binding, feed: public_feed)
    connection.destroy!

    assert public_feed.reload.update(private: true)
  end

  it "preserves the feed and its associations when delivery prevents deletion" do
    public_feed = create(:public_feed, podcast: podcast)
    connection = create(:apple_show_feed_binding, feed: public_feed)
    config = create(:delegated_delivery_config, feed: delivery_feed, key: key, show_feed_binding: connection)
    episode = create(:episode, podcast: podcast)
    public_feed.episodes << episode

    refute public_feed.destroy
    assert_includes public_feed.errors[:base], "Cannot delete a feed while delegated delivery uses its Apple connection"
    assert_nil public_feed.reload.deleted_at
    assert_equal connection, config.reload.show_feed_binding
    assert_includes public_feed.episodes, episode
  end

  it "allows deletion after dependent delivery is removed" do
    public_feed = create(:public_feed, podcast: podcast)
    connection = create(:apple_show_feed_binding, feed: public_feed)
    config = create(:delegated_delivery_config, feed: delivery_feed, key: key, show_feed_binding: connection)
    config.destroy!

    assert public_feed.reload.destroy
    refute Apple::ShowFeedBinding.exists?(connection.id)
  end

  it "allows deleting the whole podcast with connected delivery feeds" do
    config = create(:delegated_delivery_config, feed: delivery_feed, key: key, show_feed_binding: binding)

    assert podcast.destroy
    refute Apple::DelegatedDeliveryConfig.exists?(config.id)
    refute Apple::ShowFeedBinding.exists?(binding.id)
  end

  it "publishes through the feed-scoped config" do
    create(:delegated_delivery_config, feed: delivery_feed, show_feed_binding: binding, publish_enabled: true)

    assert delivery_feed.reload.publish_to_apple?
    assert delivery_feed.publish_integration?(:apple)
  end

  it "does not publish when delegated delivery is disabled" do
    create(:delegated_delivery_config, feed: delivery_feed, show_feed_binding: binding, publish_enabled: false)

    refute delivery_feed.reload.publish_to_apple?
    refute delivery_feed.publish_integration?(:apple)
    assert_equal [:apple], delivery_feed.integration_types
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
    assert_empty delivery_feed.integration_types
  end

  it "includes uploadable drafts when the default feed has delegated delivery" do
    create(:delegated_delivery_config, feed: podcast.default_feed, show_feed_binding: binding)
    draft = create(:episode_with_media, podcast: podcast, published_at: nil)

    assert_includes podcast.default_feed.integration_draft_episodes(:apple), draft
    assert podcast.default_feed.integration_episode?(draft, :apple)
    refute podcast.default_feed.feed_episode?(draft)
  end

  it "excludes drafts from feeds without Apple delegated delivery" do
    draft = create(:episode_with_media, podcast: podcast, published_at: nil)

    assert_empty podcast.default_feed.integration_draft_episodes(:apple)
    refute podcast.default_feed.integration_episode?(draft, :apple)
  end
  describe "#integration_draft_episodes" do
    [-1.day.to_i, 0, 1.day.to_i].each do |offset|
      it "partitions episodes at the release boundary with offset #{offset}" do
        freeze_time do
          apple_feed.update!(episode_offset_seconds: offset, display_episodes_count: nil)
          cutoff = Time.current - offset
          released = create(:episode, podcast: podcast, published_at: cutoff - 1.second)
          boundary = create(:episode, podcast: podcast, published_at: cutoff)
          upcoming = create(:episode, podcast: podcast, published_at: cutoff + 1.second)
          draft = create(:episode, podcast: podcast, published_at: nil)

          assert_equal [boundary.id, released.id].sort, apple_feed.feed_episode_ids.sort
          assert_equal [upcoming.id, draft.id].sort, apple_feed.integration_draft_episodes(:apple).pluck(:id).sort
        end
      end
    end

    it "returns draft and scheduled episodes" do
      apple_feed.save!
      draft = create(:episode, podcast: podcast, published_at: nil)
      scheduled = create(:episode, podcast: podcast, published_at: 1.day.from_now)
      published = create(:episode, podcast: podcast, published_at: 1.day.ago)

      result = apple_feed.integration_draft_episodes(:apple)
      assert_includes result, draft
      assert_includes result, scheduled
      refute_includes result, published
    end
  end

  describe "Apple delivery on a Megaphone feed" do
    let(:mixed_feed) { create(:megaphone_feed, podcast: podcast) }

    before do
      create(:delegated_delivery_config, feed: mixed_feed, show_feed_binding: binding)
      mixed_feed.reload
    end

    it "builds each facade without confusing their configurations" do
      episode = create(:episode, podcast: podcast, published_at: 1.hour.ago)

      assert_equal [:apple, :megaphone], mixed_feed.integration_types
      assert_equal mixed_feed.delegated_delivery_config, mixed_feed.integration_config(:apple)
      assert_equal mixed_feed.megaphone_config, mixed_feed.integration_config(:megaphone)
      assert_instance_of Apple::Episode, mixed_feed.integration_episode(episode, :apple)
      assert_equal binding.apple_show_id, mixed_feed.integration_episode(episode, :apple).apple_show_id
      assert_instance_of Megaphone::Episode, mixed_feed.integration_episode(episode, :megaphone)
      assert_equal [mixed_feed], episode.integration_feeds(:apple)
      assert_equal [mixed_feed], episode.integration_feeds(:megaphone)
    end

    it "publishes each integration with its own publisher" do
      apple_publisher = Minitest::Mock.new
      apple_publisher.expect(:publish!, :published_apple)
      megaphone_publisher = Minitest::Mock.new
      megaphone_publisher.expect(:publish!, :published_megaphone)

      mixed_feed.delegated_delivery_config.stub(:build_publisher, apple_publisher) do
        Megaphone::Publisher.stub(:new, ->(feed) {
          assert_equal mixed_feed, feed
          megaphone_publisher
        }) do
          assert_equal :published_apple, mixed_feed.publish_integration!(:apple)
          assert_equal :published_megaphone, mixed_feed.publish_integration!(:megaphone)
        end
      end

      apple_publisher.verify
      megaphone_publisher.verify
    end

    it "keeps Apple draft eligibility separate from Megaphone's RSS window" do
      draft = create(:episode_with_media, podcast: podcast, published_at: nil)

      assert_includes mixed_feed.integration_draft_episodes(:apple), draft
      assert_empty mixed_feed.integration_draft_episodes(:megaphone)
      assert_equal [mixed_feed], draft.integration_feeds(:apple)
      assert_empty draft.integration_feeds(:megaphone)
    end

    it "keeps Apple enabled when Megaphone is paused" do
      mixed_feed.megaphone_config.update!(publish_enabled: false)

      assert_equal [:apple, :megaphone], mixed_feed.integration_types
      assert mixed_feed.publish_integration?(:apple)
      refute mixed_feed.publish_integration?(:megaphone)
      assert mixed_feed.serve_drafts
      assert podcast.publish_to_integration?(:apple)
      refute podcast.publish_to_integration?(:megaphone)
    end

    it "keeps Megaphone enabled when Apple is paused" do
      mixed_feed.delegated_delivery_config.update!(publish_enabled: false)

      assert_equal [:apple, :megaphone], mixed_feed.integration_types
      refute mixed_feed.publish_integration?(:apple)
      assert mixed_feed.publish_integration?(:megaphone)
      assert mixed_feed.serve_drafts
      refute podcast.publish_to_integration?(:apple)
      assert podcast.publish_to_integration?(:megaphone)
    end
  end

  describe "#integration_episode" do
    it "resolves the show-scoped sync log through the integration facade" do
      episode = create(:episode, podcast: podcast)
      apple_feed = create(:apple_feed, podcast: podcast, apple_show_id: "show-1")
      sync_log = SyncLog.create!(
        integration: :apple,
        feeder_type: :episodes,
        feeder_id: episode.id,
        external_id: "episode-1",
        external_show_id: "show-1"
      )

      assert_equal sync_log, apple_feed.integration_episode(episode, :apple).sync_log
    end

    it "builds the Apple facade scoped to this feed's show" do
      apple_feed.save!
      episode = create(:episode, podcast: podcast, published_at: 1.hour.ago)

      facade = apple_feed.integration_episode(episode, :apple)

      assert_instance_of Apple::Episode, facade
      assert_equal apple_feed.delegated_delivery_config.apple_show_id, facade.apple_show_id
      assert_equal episode, facade.feeder_episode
    end

    it "returns nil for feeds without an integration" do
      episode = create(:episode, podcast: podcast, published_at: 1.hour.ago)

      assert_nil podcast.default_feed.integration_episode(episode, :apple)
    end
  end

  describe "#integration_episode?" do
    it "keeps early releases beyond the feed limit out of both episode sets" do
      apple_feed.update!(episode_offset_seconds: -1.day.to_i, display_episodes_count: 1)
      excluded = create(:episode_with_media, podcast: podcast, published_at: 1.hour.from_now)
      included = create(:episode_with_media, podcast: podcast, published_at: 2.hours.from_now)

      assert_equal [included.id], apple_feed.feed_episode_ids
      assert_empty apple_feed.integration_draft_episodes(:apple)
      refute apple_feed.integration_episode?(excluded, :apple)
      assert apple_feed.integration_episode?(included, :apple)
    end

    it "returns true for published episodes in feed_episodes" do
      apple_feed.save!
      published = create(:episode, podcast: podcast, published_at: 1.hour.ago)

      assert apple_feed.integration_episode?(published, :apple)
    end

    it "returns false for published episodes not in feed_episodes" do
      apple_feed.save!
      published = create(:episode, podcast: podcast, published_at: 1.hour.ago)
      # remove from the apple feed's episodes
      apple_feed.episodes_feeds.where(episode: published).delete_all

      refute apple_feed.integration_episode?(published, :apple)
    end

    it "returns true for draft and scheduled episodes with uploadable media" do
      apple_feed.save!
      draft = create(:episode_with_media, podcast: podcast, published_at: nil)
      scheduled = create(:episode_with_media, podcast: podcast, published_at: 1.day.from_now)

      assert apple_feed.integration_episode?(draft, :apple)
      assert apple_feed.integration_episode?(scheduled, :apple)
    end

    it "returns false for draft episodes with no media" do
      apple_feed.save!
      no_media = create(:episode, podcast: podcast, published_at: nil)

      refute apple_feed.integration_episode?(no_media, :apple)
    end

    it "returns false for draft episodes with incomplete media (enclosure not complete)" do
      apple_feed.save!
      processing = create(:episode,
        podcast: podcast,
        published_at: nil,
        medium: "audio",
        segment_count: 1,
        contents: [build(:content, status: "processing")])

      # enclosure_ready?(false) would be true, but enclosure_ready?(true) is false
      assert processing.enclosure_ready?(false)
      refute processing.enclosure_ready?(true)
      refute apple_feed.integration_episode?(processing, :apple)
    end

    it "returns false for draft episodes that are not feed-ready" do
      apple_feed.save!
      not_ready = create(:episode,
        podcast: podcast,
        published_at: nil,
        medium: "audio",
        segment_count: 1,
        contents: [build(:content, status: "created")])

      refute apple_feed.integration_episode?(not_ready, :apple)
    end

    it "returns false for draft episodes not assigned to this feed" do
      apple_feed.save!
      draft = create(:episode_with_media, podcast: podcast, published_at: nil)
      # verify it's initially included
      assert apple_feed.integration_episode?(draft, :apple)

      # remove from the apple feed
      apple_feed.episodes_feeds.where(episode: draft).delete_all
      apple_feed.reload

      refute apple_feed.integration_episode?(draft, :apple)
    end
  end
end
