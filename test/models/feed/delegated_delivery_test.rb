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

  it "includes uploadable drafts when the default feed has delegated delivery" do
    create(:delegated_delivery_config, feed: podcast.default_feed, show_feed_binding: binding)
    draft = create(:episode_with_media, podcast: podcast, published_at: nil)

    assert_includes podcast.default_feed.integration_draft_episodes, draft
    assert podcast.default_feed.integration_episode?(draft)
    refute podcast.default_feed.feed_episode?(draft)
  end

  it "excludes drafts from feeds without Apple delegated delivery" do
    draft = create(:episode_with_media, podcast: podcast, published_at: nil)

    assert_empty podcast.default_feed.integration_draft_episodes
    refute podcast.default_feed.integration_episode?(draft)
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
          assert_equal [upcoming.id, draft.id].sort, apple_feed.integration_draft_episodes.pluck(:id).sort
        end
      end
    end

    it "returns draft and scheduled episodes" do
      apple_feed.save!
      draft = create(:episode, podcast: podcast, published_at: nil)
      scheduled = create(:episode, podcast: podcast, published_at: 1.day.from_now)
      published = create(:episode, podcast: podcast, published_at: 1.day.ago)

      result = apple_feed.integration_draft_episodes
      assert_includes result, draft
      assert_includes result, scheduled
      refute_includes result, published
    end
  end

  describe "#integration_episode?" do
    it "keeps early releases beyond the feed limit out of both episode sets" do
      apple_feed.update!(episode_offset_seconds: -1.day.to_i, display_episodes_count: 1)
      excluded = create(:episode_with_media, podcast: podcast, published_at: 1.hour.from_now)
      included = create(:episode_with_media, podcast: podcast, published_at: 2.hours.from_now)

      assert_equal [included.id], apple_feed.feed_episode_ids
      assert_empty apple_feed.integration_draft_episodes
      refute apple_feed.integration_episode?(excluded)
      assert apple_feed.integration_episode?(included)
    end

    it "returns true for published episodes in feed_episodes" do
      apple_feed.save!
      published = create(:episode, podcast: podcast, published_at: 1.hour.ago)

      assert apple_feed.integration_episode?(published)
    end

    it "returns false for published episodes not in feed_episodes" do
      apple_feed.save!
      published = create(:episode, podcast: podcast, published_at: 1.hour.ago)
      # remove from the apple feed's episodes
      apple_feed.episodes_feeds.where(episode: published).delete_all

      refute apple_feed.integration_episode?(published)
    end

    it "returns true for draft and scheduled episodes with uploadable media" do
      apple_feed.save!
      draft = create(:episode_with_media, podcast: podcast, published_at: nil)
      scheduled = create(:episode_with_media, podcast: podcast, published_at: 1.day.from_now)

      assert apple_feed.integration_episode?(draft)
      assert apple_feed.integration_episode?(scheduled)
    end

    it "returns false for draft episodes with no media" do
      apple_feed.save!
      no_media = create(:episode, podcast: podcast, published_at: nil)

      refute apple_feed.integration_episode?(no_media)
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
      refute apple_feed.integration_episode?(processing)
    end

    it "returns false for draft episodes that are not feed-ready" do
      apple_feed.save!
      not_ready = create(:episode,
        podcast: podcast,
        published_at: nil,
        medium: "audio",
        segment_count: 1,
        contents: [build(:content, status: "created")])

      refute apple_feed.integration_episode?(not_ready)
    end

    it "returns false for draft episodes not assigned to this feed" do
      apple_feed.save!
      draft = create(:episode_with_media, podcast: podcast, published_at: nil)
      # verify it's initially included
      assert apple_feed.integration_episode?(draft)

      # remove from the apple feed
      apple_feed.episodes_feeds.where(episode: draft).delete_all
      apple_feed.reload

      refute apple_feed.integration_episode?(draft)
    end
  end
end
