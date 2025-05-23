require "test_helper"

class AppleDeliveryTest < ActiveSupport::TestCase
  let(:episode) { create(:episode_with_media) }

  describe "#apple_episode" do
    let(:episode) { create(:episode) }
    it "gets nil for no apple episode" do
      assert_nil episode.apple_episode
    end
  end

  describe "#apple_needs_delivery?" do
    let(:episode) { create(:episode) }
    it "is true by default" do
      refute episode.apple_episode_delivery_status.persisted?
      assert episode.apple_needs_delivery?
    end

    it "can be set to false" do
      episode.apple_mark_as_delivered!
      refute episode.apple_needs_delivery?
    end

    it "can be set to true" do
      episode.apple_mark_as_delivered!
      refute episode.apple_needs_delivery?

      # now set it to true
      episode.apple_mark_as_not_delivered!
      assert episode.apple_needs_delivery?
    end
  end

  describe "#apple_mark_as_delivered!" do
    let(:episode) { create(:episode) }

    it "supercedes the uploaded status" do
      episode.apple_mark_as_not_delivered!

      assert episode.apple_needs_upload?
      assert episode.apple_needs_delivery?

      episode.apple_mark_as_delivered!

      refute episode.apple_needs_upload?
      refute episode.apple_needs_delivery?
    end
  end

  describe "#apple_mark_as_uploaded!" do
    it "sets the uploaded status" do
      episode.apple_mark_as_uploaded!
      assert episode.apple_episode_delivery_status.uploaded
      refute episode.apple_needs_upload?
    end

    it "does not interact with the delivery status" do
      episode.apple_mark_as_uploaded!
      assert episode.apple_needs_delivery?
    end
  end

  describe "#increment_asset_wait" do
    let(:episode) { create(:episode) }

    it "creates a new status with incremented asset_processing_attempts" do
      assert_difference -> { episode.apple_episode_delivery_statuses.count }, 1 do
        new_status = episode.apple_status.increment_asset_wait
        assert_equal 1, new_status.asset_processing_attempts
      end
    end

    it "increments existing asset_processing_attempts" do
      create(:apple_episode_delivery_status, episode: episode, asset_processing_attempts: 2)
      new_status = episode.apple_status.increment_asset_wait
      assert_equal 3, new_status.asset_processing_attempts
    end

    it "maintains other attributes when incrementing" do
      create(:apple_episode_delivery_status,
        episode: episode,
        delivered: true,
        source_url: "http://example.com/audio.mp3",
        asset_processing_attempts: 1)

      new_status = episode.apple_status.increment_asset_wait
      assert_equal 2, new_status.asset_processing_attempts
      assert new_status.delivered
      assert_equal "http://example.com/audio.mp3", new_status.source_url
    end

    it "creates a new status with asset_processing_attempts set to 1 if no previous status exists" do
      episode.apple_episode_delivery_statuses.destroy_all
      assert_difference -> { episode.apple_episode_delivery_statuses.count }, 1 do
        new_status = episode.apple_status.increment_asset_wait
        assert_equal 1, new_status.asset_processing_attempts
      end
    end

    it "returns the new status" do
      result = episode.apple_status.increment_asset_wait
      assert_instance_of Integrations::EpisodeDeliveryStatus, result
      assert_equal episode.apple_episode_delivery_statuses.last, result
    end
  end

  describe "#publish_to_apple?" do
    let(:episode) { create(:episode) }

    it "returns false when podcast has no apple config" do
      refute episode.publish_to_apple?
    end

    it "returns false when apple config exists but publishing disabled" do
      create(:apple_config, feed: create(:private_feed, podcast: episode.podcast), publish_enabled: false)
      refute episode.publish_to_apple?
    end

    it "returns true when apple config exists and publishing enabled" do
      assert episode.publish_to_apple? == false
      create(:apple_config, feed: create(:private_feed, podcast: episode.podcast), publish_enabled: true)
      episode.podcast.reload
      assert episode.publish_to_apple?
    end
  end

  describe "#apple_prepare_for_delivery!" do
    let(:episode) { create(:episode) }
    let(:container) { create(:apple_podcast_container, episode: episode) }
    let(:delivery) { create(:apple_podcast_delivery, episode: episode, podcast_container: container) }
    let(:delivery_file) { create(:apple_podcast_delivery_file, episode: episode, podcast_delivery: delivery) }

    before do
      delivery_file # Create the delivery file
    end

    it "soft deletes existing deliveries" do
      assert_equal 1, episode.apple_podcast_deliveries.count
      episode.apple_prepare_for_delivery!
      assert_equal 0, episode.apple_podcast_deliveries.count
      assert_equal 1, episode.apple_podcast_deliveries.with_deleted.count
    end

    it "resets associations" do
      episode.apple_prepare_for_delivery!
      refute episode.apple_podcast_deliveries.loaded?
      refute episode.apple_podcast_delivery_files.loaded?
      refute episode.apple_podcast_container.podcast_deliveries.loaded?
    end
  end
end
