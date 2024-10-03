require "test_helper"

class Apple::EpisodeDeliveryStatusTest < ActiveSupport::TestCase
  describe Apple::EpisodeDeliveryStatus do
    let(:episode) { create(:episode) }
    let(:delivery_status) { create(:apple_episode_delivery_status, episode: episode) }

    describe "associations" do
      it "belongs to an episode" do
        assert_equal episode, delivery_status.episode
      end
    end

    describe "scopes" do
      it "orders by created_at desc by default" do
        old_status = create(:apple_episode_delivery_status, episode: episode, created_at: 2.days.ago)
        new_status = create(:apple_episode_delivery_status, episode: episode, created_at: 1.day.ago)

        assert_equal [new_status, old_status], episode.apple_episode_delivery_statuses.to_a
      end
    end

    describe "default values" do
      it "sets asset_processing_attempts to 0 by default" do
        new_status = Apple::EpisodeDeliveryStatus.new
        assert_equal 0, new_status.asset_processing_attempts
      end
    end

    describe "#apple_update_delivery_status" do
      it "creates a new status when none exists" do
        episode.apple_episode_delivery_statuses.destroy_all
        assert_difference "Apple::EpisodeDeliveryStatus.count", 1 do
          episode.apple_update_delivery_status(delivered: true)
        end
      end

      it "creates a new status even when one already exists" do
        _existing_status = create(:apple_episode_delivery_status, episode: episode)
        assert_difference "Apple::EpisodeDeliveryStatus.count", 1 do
          episode.apple_update_delivery_status(delivered: false)
        end
      end

      it "updates attributes of the new status" do
        new_status = episode.apple_update_delivery_status(
          delivered: true,
          source_url: "http://example.com/audio.mp3",
          source_size: 1024,
          source_filename: "audio.mp3"
        )

        assert new_status.delivered
        assert_equal "http://example.com/audio.mp3", new_status.source_url
        assert_equal 1024, new_status.source_size
        assert_equal "audio.mp3", new_status.source_filename
      end
    end

    describe "#apple_episode_delivery_status" do
      it "returns the most recent status" do
        _old_status = create(:apple_episode_delivery_status, episode: episode, created_at: 2.days.ago)
        new_status = create(:apple_episode_delivery_status, episode: episode, created_at: 1.day.ago)

        assert_equal new_status, episode.apple_episode_delivery_status
      end
    end
  end
end
