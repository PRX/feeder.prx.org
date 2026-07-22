require "test_helper"

class Integrations::EpisodeDeliveryStatusTest < ActiveSupport::TestCase
  describe "integration STI" do
    let(:episode) { create(:episode) }

    it "uses the Megaphone subclass for new and persisted Megaphone rows" do
      status = Integrations::EpisodeDeliveryStatus.create!(episode: episode, integration: :megaphone)

      assert_instance_of Megaphone::EpisodeDeliveryStatus, status
      assert_instance_of Megaphone::EpisodeDeliveryStatus,
        Integrations::EpisodeDeliveryStatus.find(status.id)
      assert_equal [status], Megaphone::EpisodeDeliveryStatus.where(id: status.id)
    end

    it "keeps Megaphone status transitions on Megaphone statuses" do
      status = build(:megaphone_episode_delivery_status, episode: episode)

      assert_respond_to status, :mark_as_uploaded!
      assert_respond_to status, :mark_as_not_uploaded!
      assert_respond_to status, :mark_as_delivered!
      assert_respond_to status, :mark_as_not_delivered!
      refute_respond_to status, :increment_asset_wait
      refute_respond_to status, :increment_asset_wait!
    end

    it "does not expose the Megaphone instance mutators on Apple statuses" do
      status = build(:apple_episode_delivery_status, episode: episode)

      refute_respond_to status, :increment_asset_wait
      refute_respond_to status, :increment_asset_wait!
      refute_respond_to status, :mark_as_uploaded!
      refute_respond_to status, :mark_as_not_uploaded!
      refute_respond_to status, :mark_as_delivered!
      refute_respond_to status, :mark_as_not_delivered!
    end
  end

  describe Integrations::EpisodeDeliveryStatus do
    let(:episode) { create(:episode) }
    let(:delivery_status) { create(:megaphone_episode_delivery_status, episode: episode) }

    describe "associations" do
      it "belongs to an episode" do
        assert_equal episode, delivery_status.episode
      end

      it "can belong to deleted episodes" do
        episode.destroy
        assert_equal episode, delivery_status.episode
        assert_difference "Integrations::EpisodeDeliveryStatus.count", +1 do
          delivery_status.mark_as_not_delivered!
        end
        assert_equal episode, Megaphone::EpisodeDeliveryStatus.current(episode).episode
      end
    end

    describe "scopes" do
      it "orders by created_at desc by default" do
        old_status = create(:megaphone_episode_delivery_status, episode: episode, created_at: 2.days.ago)
        new_status = create(:megaphone_episode_delivery_status, episode: episode, created_at: 1.day.ago)

        assert_equal [new_status, old_status], episode.episode_delivery_statuses.megaphone.to_a
      end
    end

    describe "default values" do
      it "sets asset_processing_attempts to 0 by default" do
        new_status = Integrations::EpisodeDeliveryStatus.new
        assert_equal 0, new_status.asset_processing_attempts
      end
    end

    describe "Megaphone::EpisodeDeliveryStatus.update_status" do
      it "creates a new status when none exists" do
        episode.episode_delivery_statuses.destroy_all
        assert_difference "Integrations::EpisodeDeliveryStatus.count", 1 do
          Megaphone::EpisodeDeliveryStatus.update_status(episode, delivered: true)
        end
      end

      it "creates a new status even when one already exists" do
        _existing_status = create(:megaphone_episode_delivery_status, episode: episode)
        assert_difference "Integrations::EpisodeDeliveryStatus.count", 1 do
          Megaphone::EpisodeDeliveryStatus.update_status(episode, delivered: false)
        end
      end

      it "updates attributes of the new status" do
        new_status = Megaphone::EpisodeDeliveryStatus.update_status(
          episode,
          {
            delivered: true,
            source_url: "http://example.com/audio.mp3",
            source_size: 1024,
            source_filename: "audio.mp3"
          }
        )

        assert new_status.delivered
        assert_equal "http://example.com/audio.mp3", new_status.source_url
        assert_equal 1024, new_status.source_size
        assert_equal "audio.mp3", new_status.source_filename
      end

      it "resets the episode's delivery-status association" do
        episode.episode_delivery_statuses.load
        Megaphone::EpisodeDeliveryStatus.update_status(episode, delivered: true)
        refute episode.episode_delivery_statuses.loaded?
      end
    end

    describe "Megaphone::EpisodeDeliveryStatus.current" do
      it "returns the most recent status" do
        _old_status = create(:megaphone_episode_delivery_status, episode: episode, created_at: 2.days.ago)
        new_status = create(:megaphone_episode_delivery_status, episode: episode, created_at: 1.day.ago)

        assert_equal new_status, Megaphone::EpisodeDeliveryStatus.current(episode)
      end
    end

    describe "Megaphone::EpisodeDeliveryStatus.delete_status" do
      it "deletes only Megaphone statuses" do
        megaphone_status = create(:megaphone_episode_delivery_status, episode: episode)
        apple_status = create(:apple_episode_delivery_status, episode: episode, apple_show_id: "show-1")

        Megaphone::EpisodeDeliveryStatus.delete_status(episode)

        refute Integrations::EpisodeDeliveryStatus.exists?(megaphone_status.id)
        assert Integrations::EpisodeDeliveryStatus.exists?(apple_status.id)
      end
    end

    describe "Megaphone::EpisodeDeliveryStatus.unfinished" do
      it "uses the latest Megaphone status when a newer Apple status exists" do
        create(:megaphone_episode_delivery_status,
          episode: episode,
          delivered: false,
          uploaded: false,
          created_at: 2.hours.ago)
        create(:apple_episode_delivery_status,
          episode: episode,
          apple_show_id: "show-1",
          delivered: true,
          uploaded: true,
          created_at: 1.hour.ago)

        episodes = Megaphone::EpisodeDeliveryStatus.unfinished(Episode.where(id: episode.id))

        assert_equal [episode], episodes
      end
    end

    describe "#mark_as_not_delivered!" do
      it "preserves source_media_version_id" do
        delivery_status.update!(source_media_version_id: 42)
        delivery_status.mark_as_not_delivered!
        new_status = Megaphone::EpisodeDeliveryStatus.current(episode)
        assert_equal 42, new_status.source_media_version_id
      end
    end
  end

  describe "#needs_upload?" do
    let(:episode) { create(:episode_with_media) }
    let(:current_version) { episode.media_version_id }
    let(:stale_version) { current_version - 1 }

    before do
      assert current_version.present?, "episode should have a media_version_id"
      refute_equal stale_version, current_version
    end

    it "returns true when not uploaded" do
      status = Megaphone::EpisodeDeliveryStatus.default_status(episode)
      assert status.needs_upload?
    end

    it "returns true when uploaded but source_media_version_id does not match" do
      status = Megaphone::EpisodeDeliveryStatus.update_status(episode,
        uploaded: true, source_media_version_id: stale_version)
      assert status.needs_upload?
    end

    it "returns false when uploaded and source_media_version_id matches" do
      status = Megaphone::EpisodeDeliveryStatus.update_status(episode,
        uploaded: true, source_media_version_id: current_version)
      refute status.needs_upload?
    end

    it "returns true when media version changes after a successful upload" do
      status = Megaphone::EpisodeDeliveryStatus.update_status(episode,
        uploaded: true, source_media_version_id: current_version)
      refute status.needs_upload?

      # Simulate media being re-processed (new media version cut)
      create(:content, episode: episode, position: 2, status: "complete")
      episode.reload.cut_media_version!

      assert status.needs_upload?
    end
  end

  describe "#needs_media_version?" do
    let(:episode) { create(:episode_with_media) }

    it "returns true when source_media_version_id is blank" do
      status = Megaphone::EpisodeDeliveryStatus.default_status(episode)
      assert status.needs_media_version?
    end

    it "returns true when source_media_version_id does not match" do
      status = Megaphone::EpisodeDeliveryStatus.update_status(episode,
        source_media_version_id: -1)
      assert status.needs_media_version?
    end

    it "returns false when source_media_version_id matches" do
      status = Megaphone::EpisodeDeliveryStatus.update_status(episode,
        source_media_version_id: episode.media_version_id)
      refute status.needs_media_version?
    end
  end

  describe "#measure_asset_processing_duration" do
    let(:episode) { create(:episode) }

    before do
      travel_to Time.now
    end

    after do
      travel_back
    end

    it "returns nil when there are no delivery statuses" do
      assert_nil measure_asset_processing_duration(episode)
    end

    it "returns nil when the latest status has zero attempts" do
      create(:megaphone_episode_delivery_status, episode: episode, asset_processing_attempts: 0, created_at: 1.hour.ago)
      assert_nil measure_asset_processing_duration(episode)
    end

    it "measures duration for contiguous increments" do
      create(:megaphone_episode_delivery_status, episode: episode, asset_processing_attempts: 0, created_at: 5.hours.ago)
      create(:megaphone_episode_delivery_status, episode: episode, asset_processing_attempts: 1, created_at: 4.hours.ago)
      create(:megaphone_episode_delivery_status, episode: episode, asset_processing_attempts: 2, created_at: 3.hours.ago)
      create(:megaphone_episode_delivery_status, episode: episode, asset_processing_attempts: 3, created_at: 2.hours.ago)
      create(:megaphone_episode_delivery_status, episode: episode, asset_processing_attempts: 4, created_at: 1.hour.ago)

      assert_equal 5, measure_asset_processing_duration(episode.reload) / 1.hour
    end

    it "measures duration for non-contiguous increments" do
      create(:megaphone_episode_delivery_status, episode: episode, asset_processing_attempts: 0, created_at: 3.hours.ago)
      create(:megaphone_episode_delivery_status, episode: episode, asset_processing_attempts: 4, created_at: 2.hours.ago)
      create(:megaphone_episode_delivery_status, episode: episode, asset_processing_attempts: 5, created_at: 1.hour.ago)

      assert_equal 3, measure_asset_processing_duration(episode) / 1.hour
    end

    it "handles reset attempts correctly" do
      create(:megaphone_episode_delivery_status, episode: episode, asset_processing_attempts: 0, created_at: 5.hours.ago)
      create(:megaphone_episode_delivery_status, episode: episode, asset_processing_attempts: 1, created_at: 4.hours.ago)
      create(:megaphone_episode_delivery_status, episode: episode, asset_processing_attempts: 2, created_at: 3.hours.ago)
      create(:megaphone_episode_delivery_status, episode: episode, asset_processing_attempts: 0, created_at: 2.hours.ago) # reset
      create(:megaphone_episode_delivery_status, episode: episode, asset_processing_attempts: 1, created_at: 1.hour.ago)

      assert_equal 2, measure_asset_processing_duration(episode) / 1.hour
    end

    it "returns nil when all attempts are zero" do
      create(:megaphone_episode_delivery_status, episode: episode, asset_processing_attempts: 0, created_at: 2.hours.ago)
      create(:megaphone_episode_delivery_status, episode: episode, asset_processing_attempts: 0, created_at: 1.hour.ago)

      assert_nil measure_asset_processing_duration(episode)
    end

    it "handles nil asset_processing_attempts correctly" do
      create(:megaphone_episode_delivery_status, episode: episode, asset_processing_attempts: 1, created_at: 1.hour.ago)

      assert_nil measure_asset_processing_duration(episode)
    end

    it "returns correct duration when latest attempt is zero" do
      create(:megaphone_episode_delivery_status, episode: episode, asset_processing_attempts: 0, created_at: 3.hours.ago)
      create(:megaphone_episode_delivery_status, episode: episode, asset_processing_attempts: 1, created_at: 2.hours.ago)
      create(:megaphone_episode_delivery_status, episode: episode, asset_processing_attempts: 0, created_at: 1.hour.ago)

      assert_nil measure_asset_processing_duration(episode)
    end
  end

  describe "integration-specific operations" do
    it "keeps persistence operations off the STI base class" do
      refute_respond_to Integrations::EpisodeDeliveryStatus, :default_status
      refute_respond_to Integrations::EpisodeDeliveryStatus, :update_status
      refute_respond_to Integrations::EpisodeDeliveryStatus, :delete_status
    end
  end

  private

  def measure_asset_processing_duration(episode)
    Integrations::EpisodeDeliveryStatus.measure_asset_processing_duration(
      episode.episode_delivery_statuses.megaphone
    )
  end
end
