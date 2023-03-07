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
    let(:pdf) { Apple::PodcastDeliveryFile.new(**pdf_resp_container) }

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
        pdf = Apple::PodcastDeliveryFile.new(**pdf_resp_container)
        assert_equal false, pdf.apple_complete?

        pdf_resp_container = build(:podcast_delivery_file_api_response, asset_delivery_state: "FAILED", asset_processing_state: asset_processing_state)
        pdf = Apple::PodcastDeliveryFile.new(**pdf_resp_container)
        assert_equal false, pdf.apple_complete?
      end
    end
  end
end
