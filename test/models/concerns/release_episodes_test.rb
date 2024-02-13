require "test_helper"

class ReleaseEpisodesTest < ActiveSupport::TestCase
  let(:episode) { create(:episode, published_at: 30.minutes.from_now) }
  let(:podcast) { episode.podcast }
  let(:feed) { podcast.default_feed }

  describe ".to_release" do
    it "returns episodes/podcasts that need release" do
      assert_empty Episode.to_release
      assert_empty Podcast.to_release

      episode.update!(published_at: 1.minute.ago)
      assert_equal [episode], Episode.to_release
      assert_equal [podcast], Podcast.to_release

      # queue item < published_at - still needs release
      PublishingQueueItem.create!(podcast: podcast, created_at: 1.hour.ago)
      assert_equal [episode], Episode.to_release
      assert_equal [podcast], Podcast.to_release

      # queue item > published_at - we're good!
      PublishingQueueItem.create!(podcast: podcast, created_at: 1.minute.from_now)
      assert_empty Episode.to_release
      assert_empty Podcast.to_release
    end

    it "handles negative feed offsets" do
      feed.update!(episode_offset_seconds: -300)
      assert_empty Episode.to_release
      assert_empty Podcast.to_release

      episode.update!(published_at: 4.minutes.from_now)
      assert_equal [episode], Episode.to_release
      assert_equal [podcast], Podcast.to_release

      # add a queue item, and we're good
      PublishingQueueItem.create!(podcast: podcast)
      assert_empty Episode.to_release
      assert_empty Podcast.to_release
    end

    it "handles positive feed offsets" do
      feed.update!(episode_offset_seconds: 300)
      assert_empty Episode.to_release
      assert_empty Podcast.to_release

      episode.update!(published_at: 4.minutes.ago)
      assert_empty Episode.to_release
      assert_empty Podcast.to_release

      episode.update!(published_at: 6.minutes.ago)
      assert_equal [episode], Episode.to_release
      assert_equal [podcast], Podcast.to_release

      # add a queue item, and we're good
      PublishingQueueItem.create!(podcast: podcast)
      assert_empty Episode.to_release
      assert_empty Podcast.to_release
    end

    it "does not care about non-published_at or deleted data" do
      episode.update!(published_at: 1.minute.ago)
      assert_equal [episode], Episode.to_release
      assert_equal [podcast], Podcast.to_release

      episode.update!(published_at: nil)
      assert_empty Episode.to_release
      assert_empty Podcast.to_release

      episode.update!(published_at: 1.minutes.ago, deleted_at: Time.now)
      assert_empty Episode.to_release
      assert_empty Podcast.to_release

      episode.update!(deleted_at: nil)
      feed.update!(deleted_at: Time.now)
      assert_empty Episode.to_release
      assert_empty Podcast.to_release
    end
  end

  describe ".release!" do
    it "publishes podcasts and updates published_at" do
      podcast.update!(published_at: 1.hour.ago)
      episode.update!(published_at: 10.minutes.ago)
      episode2 = create(:episode, podcast: podcast, published_at: 1.minute.ago)

      publish_calls = []

      Podcast.stub_any_instance(:publish!, -> { publish_calls << self }) do
        Podcast.release!
      end

      assert_equal [podcast], publish_calls
      assert_equal podcast.published_at, episode2.published_at
    end

    it "cleans up dead publishing pipelines" do
      obj = Minitest::Mock.new
      obj.expect :call, nil
      PublishingPipelineState.stub(:expire_pipelines!, obj) do
        Podcast.release!
      end
      obj.verify
    end

    it "retries latest publishing pipelines with errors" do
      obj = Minitest::Mock.new
      obj.expect :call, nil
      PublishingPipelineState.stub(:retry_failed_pipelines!, obj) do
        Podcast.release!
      end
      obj.verify
    end
  end
end
