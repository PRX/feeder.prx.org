require "test_helper"

class AppleIntegrationTest < ActiveSupport::TestCase
  let(:podcast) { create(:podcast) }
  let(:episode) { create(:episode, podcast: podcast) }

  describe "#apple_episode" do
    it "returns nil without an Apple configuration" do
      assert_nil episode.apple_episode
    end

    it "returns nil without a show identity" do
      create(:apple_feed, podcast: podcast)

      assert_nil episode.apple_episode
    end

    it "returns a show-scoped facade" do
      create(:apple_feed, podcast: podcast, apple_show_id: "show-1")

      assert_equal "show-1", episode.apple_episode.apple_show_id
    end

    it "resolves the show-scoped sync log through the integration facade" do
      create(:apple_feed, podcast: podcast, apple_show_id: "show-1")
      sync_log = SyncLog.create!(
        integration: :apple,
        feeder_type: :episodes,
        feeder_id: episode.id,
        external_id: "episode-1",
        apple_show_id: "show-1"
      )

      assert_equal sync_log, episode.integration_episode(:apple).sync_log
    end
  end

  describe "unscoped Apple resources" do
    it "keeps raw Apple associations private" do
      refute episode.respond_to?(:apple_sync_log)
      refute episode.respond_to?(:apple_podcast_containers)
      refute episode.respond_to?(:sync_logs)

      assert_raises(NoMethodError) { episode.apple_sync_log }
      assert_raises(NoMethodError) { episode.apple_podcast_containers }
      assert_raises(NoMethodError) { episode.sync_logs }
    end

    it "does not expose legacy Apple state methods" do
      %i[
        apple_episode_delivery_status
        apple_episode_delivery_statuses
        apple_mark_as_delivered!
        apple_prepare_for_delivery!
        apple_update_delivery_status
      ].each do |method_name|
        refute episode.respond_to?(method_name), method_name
      end
    end
  end

  describe "#publish_to_apple?" do
    it "returns false when podcast has no apple config" do
      refute episode.publish_to_apple?
    end

    it "returns false when publishing is disabled" do
      create(:apple_config, feed: create(:private_feed, podcast: podcast), publish_enabled: false)

      refute episode.publish_to_apple?
    end

    it "returns true when publishing is enabled" do
      create(:apple_config, feed: create(:private_feed, podcast: podcast), publish_enabled: true)
      podcast.reload

      assert episode.publish_to_apple?
    end
  end
end
