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
      episode.apple_has_delivery!
      refute episode.apple_needs_delivery?
    end

    it "can be set to true" do
      episode.apple_has_delivery!
      refute episode.apple_needs_delivery?

      # now set it to true
      episode.apple_needs_delivery!
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
      assert_instance_of Apple::EpisodeDeliveryStatus, result
      assert_equal episode.apple_episode_delivery_statuses.last, result
    end
  end
end
