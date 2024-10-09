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

    describe ".update_status" do
      it "creates a new status when none exists" do
        episode.apple_episode_delivery_statuses.destroy_all
        assert_difference "Apple::EpisodeDeliveryStatus.count", 1 do
          Apple::EpisodeDeliveryStatus.update_status(episode, delivered: true)
        end
      end

      it "creates a new status even when one already exists" do
        _existing_status = create(:apple_episode_delivery_status, episode: episode)
        assert_difference "Apple::EpisodeDeliveryStatus.count", 1 do
          Apple::EpisodeDeliveryStatus.update_status(episode, delivered: false)
        end
      end

      it "updates attributes of the new status" do
        new_status = Apple::EpisodeDeliveryStatus.update_status(episode,
          delivered: true,
          source_url: "http://example.com/audio.mp3",
          source_size: 1024,
          source_filename: "audio.mp3")

        assert new_status.delivered
        assert_equal "http://example.com/audio.mp3", new_status.source_url
        assert_equal 1024, new_status.source_size
        assert_equal "audio.mp3", new_status.source_filename
      end

      it "resets the episode's apple_episode_delivery_statuses association" do
        episode.apple_episode_delivery_statuses.load
        Apple::EpisodeDeliveryStatus.update_status(episode, delivered: true)
        refute episode.apple_episode_delivery_statuses.loaded?
      end
    end

    describe "Episode#apple_episode_delivery_status" do
      it "returns the most recent status" do
        _old_status = create(:apple_episode_delivery_status, episode: episode, created_at: 2.days.ago)
        new_status = create(:apple_episode_delivery_status, episode: episode, created_at: 1.day.ago)

        assert_equal new_status, episode.apple_episode_delivery_status
      end
    end

    describe "Asset waits and counting" do
      describe "#increment_asset_wait" do
        it "increments the asset_processing_attempts count" do
          initial_count = delivery_status.asset_processing_attempts || 0
          new_status = delivery_status.increment_asset_wait
          assert_equal initial_count + 1, new_status.asset_processing_attempts
        end

        it "creates a new status entry" do
          assert delivery_status.asset_processing_attempts.zero?
          assert_difference "Apple::EpisodeDeliveryStatus.count", 1 do
            delivery_status.increment_asset_wait
          end
        end

        it "maintains other attributes" do
          delivery_status.update(delivered: true, source_url: "http://example.com/audio.mp3")
          new_status = delivery_status.increment_asset_wait
          assert new_status.delivered
          assert_equal "http://example.com/audio.mp3", new_status.source_url
        end
      end

      describe "#reset_asset_wait" do
        it "resets the asset_processing_attempts count to zero" do
          delivery_status.update(asset_processing_attempts: 5)
          new_status = delivery_status.reset_asset_wait
          assert_equal 0, new_status.asset_processing_attempts
        end

        it "creates a new status entry" do
          assert delivery_status.asset_processing_attempts.zero?
          assert_difference "Apple::EpisodeDeliveryStatus.count", 1 do
            delivery_status.reset_asset_wait
          end
        end

        it "maintains other attributes" do
          delivery_status.update(delivered: true, source_url: "http://example.com/audio.mp3")
          new_status = delivery_status.reset_asset_wait
          assert new_status.delivered
          assert_equal "http://example.com/audio.mp3", new_status.source_url
        end
      end
    end
  end
end
