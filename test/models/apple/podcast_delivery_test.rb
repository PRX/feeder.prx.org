# frozen_string_literal: true

require "test_helper"

class Apple::PodcastDeliveryTest < ActiveSupport::TestCase
  let(:podcast_delivery_json) { {data: {id: "123"}} }
  let(:podcast_delivery_json_api_response) { {api_response: {val: podcast_delivery_json}}.with_indifferent_access }
  describe ".upsert_podcast_delivery" do
    let(:podcast) { create(:podcast) }
    let(:feed) { create(:feed, podcast: podcast, private: false) }
    let(:episode) { create(:episode, podcast: podcast) }
    let(:apple_show) { Apple::Show.new(feed) }
    let(:apple_episode) { build(:apple_episode, show: apple_show, feeder_episode: episode) }

    let(:podcast_container) do
      pc = Apple::PodcastContainer.new
      pc.episode = episode
      pc.vendor_id = "123"
      pc.apple_episode_id = "123"
      pc.save!
      pc
    end

    it "should create a single log based on a returned row value" do
      assert_equal SyncLog.count, 0
      assert_equal Apple::PodcastDelivery.count, 0

      Apple::PodcastDelivery.upsert_podcast_delivery(podcast_container, podcast_delivery_json_api_response)

      assert_equal SyncLog.count, 1
      assert_equal Apple::PodcastDelivery.count, 1

      # Now upsert existing record
      Apple::PodcastDelivery.upsert_podcast_delivery(podcast_container, podcast_delivery_json_api_response)

      assert_equal SyncLog.count, 1
      assert_equal Apple::PodcastDelivery.count, 1
    end

    it "should update timestamps" do
      pd = Apple::PodcastDelivery.upsert_podcast_delivery(podcast_container, podcast_delivery_json_api_response)

      # Now upsert existing record and overwrite timestamps
      pd.update(updated_at: Time.now - 1.year)
      # modify the json so that the podcast_delivery_changes
      pd2 = Apple::PodcastDelivery.upsert_podcast_delivery(podcast_container, podcast_delivery_json_api_response)
      assert pd2.updated_at > pd.updated_at
    end

    it "should update the delivery status" do
      res = Apple::PodcastDelivery.upsert_podcast_delivery(podcast_container, podcast_delivery_json_api_response)
      assert_nil res.status

      Apple::PodcastDelivery.upsert_podcast_delivery(podcast_container,
        {api_response: {val: {data: {id: "123", attributes: {status: "COMPLETED"}}}}}.with_indifferent_access)

      assert_equal "completed", res.reload.status
    end
  end

  describe "#podcast_delivery" do
    let(:container) { Apple::PodcastContainer.new }
    it "should have many deliveries" do
      assert_equal [], container.podcast_deliveries
      pd = container.podcast_deliveries.build
      assert_equal Apple::PodcastDelivery, pd.class
    end
  end

  describe "get_podcast_containers_deliveries_bridge_param" do
    it "should format a single bridge param row" do
      assert_equal({
        request_metadata: {
          apple_episode_id: "some-apple-id",
          podcast_container_id: "podcast-container-id"
        },
        api_url: "http://apple", api_parameters: {}
      },
        Apple::PodcastDelivery.get_podcast_containers_deliveries_bridge_param(OpenStruct.new(apple_episode_id: "some-apple-id", id: "podcast-container-id", podcast_deliveries_url: "http://apple")))
    end
  end

  describe ".get_urls_for_container_podcast_deliveries" do
    let(:podcast_container_deliveries_json) do
      {"request_metadata" => {"apple_episode_id" => "apple-episode-id", "podcast_container_id" => 1},
       "api_url" => "https://aardvark.prx.org/podcastContainers/12345/relationships/podcastDeliveries",
       "api_parameters" => {},
       "api_response" => {"ok" => true,
                          "err" => false,
                          "val" =>
                        {"data" => [{"type" => "podcastDeliveries",
                                     "id" => "1111111111111111111111111"}]}}}
    end
    let(:apple_api) { build(:apple_api) }

    it "should format a new set of podcast delivery urls" do
      assert_equal ["https://aardvark.prx.org/podcastDeliveries/1111111111111111111111111"],
        Apple::PodcastDelivery.get_urls_for_container_podcast_deliveries(apple_api,
          podcast_container_deliveries_json)
    end
  end

  describe ".get_podcast_deliveries_via_containers" do
    let(:episode) { create(:episode) }
    let(:podcast_container) do
      create(:apple_podcast_container,
        episode: episode,
        apple_episode_id: "apple-episode-id",
        external_id: "stale-container-id")
    end

    def fake_delivery_api(response, errs)
      Class.new do
        attr_reader :calls, :raised_errs

        def initialize(response, errs)
          @response = response
          @errs = errs
          @calls = []
        end

        def bridge_remote_and_retry(resource, params, batch_size:)
          @calls << {resource: resource, params: params, batch_size: batch_size}
          [@response, @errs]
        end

        def raise_bridge_api_error(errs)
          @raised_errs = errs
          raise Apple::ApiError.new("Apple API Bridge Error", nil)
        end
      end.new(response, errs)
    end

    it "resets stale local containers and raises for retry when container delivery polling returns 404" do
      delivery = create(:apple_podcast_delivery, episode: episode, podcast_container: podcast_container)
      delivery_file = create(:apple_podcast_delivery_file, episode: episode, podcast_delivery: delivery)
      create(:apple_episode_delivery_status,
        episode: episode,
        delivered: true,
        uploaded: true,
        asset_processing_attempts: 3)
      not_found_err = {
        "request_metadata" => {"podcast_container_id" => podcast_container.id},
        "api_response" => {"val" => {"data" => {"status" => Apple::Api::NOT_FOUND}}}
      }
      fake_api = fake_delivery_api([], [not_found_err])

      error = assert_raises(Apple::RetryPublishingError) do
        Apple::PodcastDelivery.get_podcast_deliveries_via_containers(fake_api, [podcast_container])
      end

      assert_match(/Reset 1 stale Apple podcast containers/, error.message)
      assert_equal 1, fake_api.calls.length
      refute Apple::PodcastContainer.exists?(podcast_container.id)
      assert Apple::PodcastDelivery.with_deleted.find(delivery.id).deleted?
      assert Apple::PodcastDeliveryFile.with_deleted.find(delivery_file.id).deleted?

      status = episode.episode_delivery_status(:apple)
      refute status.delivered?
      refute status.uploaded?
      assert_equal 0, status.asset_processing_attempts
    end

    it "handles the production bridge 404 payload for deleted podcast containers" do
      delivery = create(:apple_podcast_delivery, episode: episode, podcast_container: podcast_container)
      delivery_file = create(:apple_podcast_delivery_file, episode: episode, podcast_delivery: delivery)
      create(:apple_episode_delivery_status,
        episode: episode,
        delivered: true,
        uploaded: true,
        asset_processing_attempts: 3)
      not_found_err = {
        "request_metadata" => {
          "apple_episode_id" => "apple-episode-id",
          "podcast_container_id" => podcast_container.id
        },
        "api_parameters" => {},
        "api_url" => "https://api.podcastsconnect.apple.com/v1/podcastContainers/13265604/podcastDeliveries",
        "api_response" => {
          "ok" => false,
          "err" => true,
          "val" => {
            "data" => {
              "body" => {
                "errors" => [{
                  "id" => "00000000-0000-4000-8000-000000000000",
                  "status" => "404",
                  "code" => "NOT_FOUND",
                  "title" => "The specified resource does not exist",
                  "detail" => "There is no resource of type 'podcastContainers' with id '13265604'"
                }]
              },
              "status" => 404,
              "context" => "response"
            }
          },
          "_stack" => "    at formatApiError (file:///var/task/api_response.js:36:12)"
        }
      }
      fake_api = fake_delivery_api([], [not_found_err])

      error = assert_raises(Apple::RetryPublishingError) do
        Apple::PodcastDelivery.get_podcast_deliveries_via_containers(fake_api, [podcast_container])
      end

      assert_match(/Reset 1 stale Apple podcast containers/, error.message)
      assert_equal 1, fake_api.calls.length
      refute Apple::PodcastContainer.exists?(podcast_container.id)
      assert Apple::PodcastDelivery.with_deleted.find(delivery.id).deleted?
      assert Apple::PodcastDeliveryFile.with_deleted.find(delivery_file.id).deleted?

      status = episode.episode_delivery_status(:apple)
      refute status.delivered?
      refute status.uploaded?
      assert_equal 0, status.asset_processing_attempts
    end

    it "preserves 404 bridge errors that do not map to a requested local container" do
      create(:apple_episode_delivery_status,
        episode: episode,
        delivered: true,
        uploaded: true,
        asset_processing_attempts: 3)
      not_found_err = {
        "request_metadata" => {"podcast_container_id" => podcast_container.id + 1},
        "api_response" => {"val" => {"data" => {"status" => Apple::Api::NOT_FOUND}}}
      }
      fake_api = fake_delivery_api([], [not_found_err])

      assert_raises(Apple::ApiError) do
        Apple::PodcastDelivery.get_podcast_deliveries_via_containers(fake_api, [podcast_container])
      end

      assert_equal [not_found_err], fake_api.raised_errs
      assert Apple::PodcastContainer.exists?(podcast_container.id)

      status = episode.episode_delivery_status(:apple)
      assert status.delivered?
      assert status.uploaded?
      assert_equal 3, status.asset_processing_attempts
    end

    it "preserves non-404 bridge errors while polling container deliveries" do
      create(:apple_episode_delivery_status,
        episode: episode,
        delivered: true,
        uploaded: true,
        asset_processing_attempts: 3)
      bridge_err = {
        "request_metadata" => {"podcast_container_id" => podcast_container.id},
        "api_response" => {"val" => {"data" => {"status" => 500}}}
      }
      fake_api = fake_delivery_api([], [bridge_err])

      assert_raises(Apple::ApiError) do
        Apple::PodcastDelivery.get_podcast_deliveries_via_containers(fake_api, [podcast_container])
      end

      assert_equal [bridge_err], fake_api.raised_errs
      assert Apple::PodcastContainer.exists?(podcast_container.id)

      status = episode.episode_delivery_status(:apple)
      assert status.delivered?
      assert status.uploaded?
      assert_equal 3, status.asset_processing_attempts
    end
  end

  describe ".select_episodes_for_delivery" do
    let(:episode1) { build(:apple_episode) }
    let(:episode2) { build(:apple_episode) }

    it "should filter/select podcasts that need delivery" do
      episode1.stub(:needs_delivery?, true) do
        episode2.stub(:needs_delivery?, false) do
          assert_equal [episode1],
            Apple::PodcastDelivery.select_episodes_for_delivery([episode1, episode2])
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

    before do
      pdf_resp_container = build(:podcast_delivery_file_api_response)
      pdf = Apple::PodcastDeliveryFile.create!(podcast_delivery: podcast_delivery, episode: podcast_container.episode)
      pdf.create_apple_sync_log!(**pdf_resp_container)
      podcast_container.reload
    end

    it "should soft delete the delivery" do
      assert podcast_container.persisted?
      assert_equal [podcast_delivery], podcast_container.podcast_deliveries

      podcast_container.stub(:missing_podcast_audio?, true) do
        assert_equal false, podcast_container.needs_delivery?
      end

      podcast_delivery.destroy

      assert_equal [], podcast_container.podcast_deliveries.reset
      assert_equal [podcast_delivery], podcast_container.podcast_deliveries.with_deleted
    end
  end

  describe "#episode" do
    let(:podcast_container) { create(:apple_podcast_container) }
    let(:podcast_delivery) {
      Apple::PodcastDelivery.create!(podcast_container: podcast_container, episode: podcast_container.episode)
    }
    it "should load a deleted episode" do
      podcast_delivery.episode.destroy
      podcast_delivery.reload
      assert_equal podcast_delivery.episode, podcast_container.episode
    end
  end
end
