require "test_helper"

class ApplePodcastDeliveryFileTest < ActiveSupport::TestCase
  describe ".select_podcast_delivery_files" do
    it "should return the apple_podcast_deliveries from the episodes" do
      ep1 = OpenStruct.new(podcast_deliveries: [1, 2])
      ep2 = OpenStruct.new(podcast_deliveries: [3])
      ep3 = OpenStruct.new(podcast_deliveries: [])

      assert_equal [1, 2, 3], Apple::PodcastDeliveryFile.select_podcast_deliveries([ep1, ep2, ep3])
    end

    it "Operates on an array of Apple::Episodes" do
      ep1 = build(:apple_episode)
      assert_equal [], Apple::PodcastDeliveryFile.select_podcast_deliveries([ep1])
    end
  end

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

        api_response = {
          request_metadata: {podcast_delivery_file_id: pdf.id, foo: 123},
          api_response: {val: {data: {id: pdf.apple_sync_log.external_id}}}
        }.with_indifferent_access

        pdf.stub(:delivery_awaiting_upload?, true) do
          apple_api.stub(:bridge_remote_and_retry, [[api_response], []]) do
            pdf.update!(api_marked_as_uploaded: false)
            Apple::PodcastDeliveryFile.mark_uploaded(apple_api, [pdf])
            assert_equal true, pdf.reload.api_marked_as_uploaded
            assert_equal 123, pdf.reload.apple_sync_log.api_response["request_metadata"]["foo"]
          end
        end
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
