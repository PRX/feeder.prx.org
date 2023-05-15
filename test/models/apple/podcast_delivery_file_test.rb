require "test_helper"

class ApplePodcastDeliveryFileTest < ActiveSupport::TestCase
  describe ".get_delivery_file_bridge_params" do
    it "should format a single bridge param row" do
      assert_equal({
        request_metadata: {
          apple_episode_id: "some-apple-id",
          podcast_delivery_id: "podcast-delivery-id",
          apple_podcast_delivery_file_id: "podcast-delivery-file-id"
        },
        api_url: "http://apple", api_parameters: {}
      },
        Apple::PodcastDeliveryFile.get_delivery_file_bridge_params("some-apple-id",
          "podcast-delivery-id",
          "podcast-delivery-file-id",
          "http://apple"))
    end
  end

  describe "delivery and processing state methods" do
    let(:asset_processing_state) { "COMPLETED" }
    let(:asset_delivery_state) { "COMPLETE" }

    let(:pdf_resp_container) { build(:podcast_delivery_file_api_response, asset_delivery_state: asset_delivery_state, asset_processing_state: asset_processing_state) }
    let(:apple_id) { {external_id: "123"} }
    let(:pdf) { Apple::PodcastDeliveryFile.new(apple_sync_log: SyncLog.new(**pdf_resp_container.merge(apple_id))) }

    describe "#delivery_awaiting_upload?" do
      it "should be false if the status is delivery_status is false" do
        assert_equal false, pdf.delivery_awaiting_upload?
      end
    end

    describe "#apple_complete?" do
      it "should be true if the the two statuses is complete" do
        assert_equal true, pdf.apple_complete?
      end

      it "will not be complete if either of the two state statues are not complete" do
        pdf_resp_container = build(:podcast_delivery_file_api_response, asset_delivery_state: asset_delivery_state, asset_processing_state: "VALIDATION_FAILED")
        pdf = Apple::PodcastDeliveryFile.new(apple_sync_log: SyncLog.new(**pdf_resp_container.merge(apple_id)))
        assert_equal false, pdf.apple_complete?

        pdf_resp_container = build(:podcast_delivery_file_api_response, asset_delivery_state: "FAILED", asset_processing_state: asset_processing_state)
        pdf = Apple::PodcastDeliveryFile.new(apple_sync_log: SyncLog.new(**pdf_resp_container.merge(apple_id)))
        assert_equal false, pdf.apple_complete?
      end
    end

    describe ".mark_existing_uploaded" do
      let(:podcast_container) { create(:apple_podcast_container, episode: episode) }
      let(:podcast_delivery) {
        Apple::PodcastDelivery.create!(podcast_container: podcast_container,
          episode: podcast_container.episode)
      }
      let(:podcast) { create(:podcast) }

      let(:public_feed) { create(:feed, podcast: podcast, private: false) }
      let(:private_feed) { create(:feed, podcast: podcast, private: true, tokens: [FeedToken.new]) }

      let(:apple_config) { build(:apple_config) }
      let(:apple_api) { Apple::Api.from_apple_config(apple_config) }

      let(:episode) { create(:episode, podcast: podcast) }
      let(:apple_show) do
        Apple::Show.new(api: apple_api,
          public_feed: public_feed,
          private_feed: private_feed)
      end
      let(:apple_episode) { build(:apple_episode, show: apple_show, feeder_episode: episode) }

      it "should mark all existing files as uploaded if the episode has ready audio" do
        pdf_resp_container = build(:podcast_delivery_file_api_response, asset_delivery_state: asset_delivery_state)
        pdf = Apple::PodcastDeliveryFile.create!(podcast_delivery: podcast_delivery, episode: podcast_container.episode)
        pdf.create_apple_sync_log!(**pdf_resp_container.merge(apple_id))

        pdf.update!(api_marked_as_uploaded: false)
        apple_episode.stub(:waiting_for_asset_state?, false) do
          Apple::PodcastDeliveryFile.mark_existing_uploaded([apple_episode])
        end
        assert_equal true, pdf.reload.api_marked_as_uploaded

        pdf.update(api_marked_as_uploaded: false)
        apple_episode.stub(:waiting_for_asset_state?, true) do
          Apple::PodcastDeliveryFile.mark_existing_uploaded([apple_episode])
        end
        assert_equal false, pdf.reload.api_marked_as_uploaded
      end
    end
  end

  describe "#destroy" do
    let(:podcast_container) { create(:apple_podcast_container) }
    let(:podcast_delivery) {
      Apple::PodcastDelivery.create!(podcast_container: podcast_container,
        episode: podcast_container.episode)
    }

    it "should soft delete the delivery" do
      pdf_resp_container = build(:podcast_delivery_file_api_response)
      pdf = Apple::PodcastDeliveryFile.create!(podcast_delivery: podcast_delivery, episode: podcast_container.episode)
      pdf.create_apple_sync_log!(**pdf_resp_container.merge(external_id: "123"))

      assert_equal [pdf], podcast_delivery.podcast_delivery_files.reset

      pdf.destroy

      assert_equal [], podcast_delivery.podcast_delivery_files.reset
    end
  end
end
