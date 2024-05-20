require "test_helper"

class EpisodeHasFeedsTest < ActiveSupport::TestCase
  let(:podcast) { create(:podcast) }
  let(:f1) { podcast.default_feed }
  let(:f2) { create(:feed, podcast: podcast, slug: "feed2") }
  let(:f3) { create(:feed, podcast: podcast, slug: "feed3") }
  let(:episode) { create(:episode, podcast: podcast) }

  before { assert [f1, f2, f3] }

  describe ".in_feed" do
    it "returns episodes in a feed" do
      e2 = create(:episode, podcast: podcast, feeds: [f2])
      e3 = create(:episode, podcast: podcast, feeds: [f2])
      assert_equal [e2, e3], Episode.in_feed(f2).order(id: :asc)

      # only includes published
      e2.update(published_at: 1.hour.from_now)
      assert_equal [e3], Episode.in_feed(f2).order(id: :asc)

      # does apply offsets
      f2.episode_offset_seconds = -3601
      assert_equal [e2, e3], Episode.in_feed(f2).order(id: :asc)

      # does NOT apply limits
      f2.display_episodes_count = 1
      assert_equal [e2, e3], Episode.in_feed(f2).order(id: :asc)
    end
  end

  describe ".in_default_feed" do
    it "returns episodes in the default feed" do
      assert_equal [episode], Episode.in_default_feed

      # unpublished episodes not in default feed
      episode.update(published_at: 1.hour.from_now)
      assert_empty Episode.in_default_feed

      # or episodes in other feeds
      episode.update(published_at: 1.hour.ago, feeds: [])
      assert_empty Episode.in_default_feed
    end
  end

  describe "#in_feed?" do
    it "checks if an episode is in a feed" do
      assert episode.in_feed?(f1)
      refute episode.in_feed?(f2)
      refute episode.in_feed?(f3)
    end
  end

  describe "#in_default_feed?" do
    it "checks if an episode is in the default feed" do
      assert episode.in_default_feed?

      episode.feeds = [f2]
      refute episode.in_default_feed?
    end
  end

  describe "#set_default_feeds" do
    it "sets default feeds on new episodes" do
      # saved episodes get default+apple feeds
      f3.update(type: "Feeds::AppleSubscription")
      assert_equal [f1.id, f3.id], episode.feeds.map(&:id).sort

      # new episodes initialized with defaults
      e2 = podcast.episodes.new
      assert_equal [f1.id, f3.id], e2.feeds.map(&:id).sort

      # UNLESS episode already has feeds
      e2 = podcast.episodes.new(feeds: [f2])
      assert_equal [f2.id], e2.feeds.map(&:id)
    end
  end

  describe "#feed_slugs" do
    it "gets and sets feeds based on their slugs" do
      assert_equal [f1], episode.feeds
      assert_equal ["default"], episode.feed_slugs

      episode.feed_slugs = ["default", "whatev", "feed3"]
      assert_equal [f1, f3], episode.feeds

      episode.feed_slugs = ["feed3"]
      assert_equal [f3], episode.feeds
    end
  end
end
