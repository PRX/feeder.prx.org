# frozen_string_literal: true

require "test_helper"

class Apple::PodcastContainerTest < ActiveSupport::TestCase
  let(:podcast) { create(:podcast) }
  let(:episode) { create(:episode, podcast: podcast) }

  let(:apple_config) { build(:apple_config) }
  let(:apple_api) { Apple::Api.from_apple_config(apple_config) }
  let(:public_feed) { podcast.default_feed }
  let(:private_feed) { create(:private_feed, podcast: podcast) }
  let(:apple_show) { Apple::Show.new(api: apple_api, public_feed: public_feed, private_feed: private_feed) }

  let(:apple_episode) { build(:apple_episode, show: apple_show, feeder_episode: episode) }

  let(:apple_episode_id) { "apple-ep-id" }
  let(:apple_audio_asset_vendor_id) { "apple-vendor-id" }
  let(:podcast_container_json_row) do
    {"request_metadata" => {"apple_episode_id" => apple_episode_id},
     "api_response" => {"val" => {"data" =>
     {"type" => "podcastContainers",
      "id" => "1234"}}}}
  end

  let(:api) { build(:apple_api) }

  describe "#episode" do
    it "can assign a soft deleted episode" do
      episode.touch(:deleted_at)
      pc = Apple::PodcastContainer.upsert_podcast_container(apple_episode, podcast_container_json_row)

      assert_equal true, pc.episode.deleted?
    end
  end

  describe "the DTR / CDN redirect flow" do
    let(:pc) { Apple::PodcastContainer.upsert_podcast_container(apple_episode, podcast_container_json_row) }

    describe ".wait_for_versioned_source_metadata" do
      it "raises when headFileSizes returns fewer rows than requested" do
        episode2 = create(:episode, podcast: podcast)
        apple_episode2 = build(:apple_episode, show: apple_show, feeder_episode: episode2)
        pc2_row = {"request_metadata" => {"apple_episode_id" => "apple-ep-id-2"},
                   "api_response" => {"val" => {"data" => {"type" => "podcastContainers", "id" => "5678"}}}}
        Apple::PodcastContainer.upsert_podcast_container(apple_episode2, pc2_row)

        # bridge returns only one row for two containers
        single_row = [{"request_metadata" => {"podcast_container_id" => pc.id},
                       "api_response" => {"val" => {"data" => {"headers" => {"content-length" => "1000"},
                                                               "redirect_chain_end_url" => "https://cdn.example.com/a.mp3",
                                                               "episode_media_version" => "99"}}}}]

        api.stub(:bridge_remote_and_retry!, single_row) do
          assert_raises(RuntimeError, /Join key mismatch/) do
            Apple::MediaInfo.probe_source_file_metadata(api, [apple_episode, apple_episode2])
          end
        end
      end

      it "should wait for the source metadata to be updated and return media_infos" do
        mock_version_id = 42

        media_info = Apple::MediaInfo.new(
          episode: apple_episode,
          source_media_version_id: mock_version_id,
          source_size: 1000,
          source_url: "https://cdn.example.com/audio.mp3"
        )

        Apple::MediaInfo.stub(:reset_source_file_metadata, nil) do
          Apple::MediaInfo.stub(:probe_source_file_metadata, [media_info]) do
            apple_episode.feeder_episode.stub(:media_version_id, mock_version_id) do
              (timed_out, media_infos) = Apple::MediaInfo.wait_for_versioned_source_metadata(api, [apple_episode], wait_interval: 0.seconds, wait_timeout: 5.seconds)
              assert_equal false, timed_out
              assert_equal 1, media_infos.length
              assert_equal apple_episode, media_infos.first.episode
            end
          end
        end
      end
    end

  end

  describe "probing source metadata" do
    let(:pc) { Apple::PodcastContainer.upsert_podcast_container(apple_episode, {"request_metadata" => {"apple_episode_id" => "apple-ep-id"}, "api_response" => {"val" => {"data" => {"type" => "podcastContainers", "id" => "1234"}}}}) }

    it "should filter episodes that lack a container" do
      apple_episode.stub(:podcast_container, nil) do
        assert_equal [], Apple::MediaInfo.probe_source_file_metadata(api, [apple_episode])
      end
    end

    it "should not filter episodes by needs_delivery" do
      response_row = {
        "request_metadata" => {"podcast_container_id" => pc.id},
        "api_response" => {
          "val" => {
            "data" => {
              "headers" => {"content-length" => "123"},
              "redirect_chain_end_url" => "https://cdn.example.com/audio.mp3",
              "episode_media_version" => "42"
            }
          }
        }
      }

      apple_episode.stub(:needs_delivery?, false) do
        api.stub(:bridge_remote_and_retry!, [response_row]) do
          media_infos = Apple::MediaInfo.probe_source_file_metadata(api, [apple_episode])
          assert_equal 1, media_infos.length
          assert_equal apple_episode, media_infos.first.episode
        end
      end
    end
  end

  describe ".upsert_podcast_containers" do
    it "should create logs based on a returned row value" do
      apple_episode.stub(:apple_id, apple_episode_id) do
        apple_episode.stub(:audio_asset_vendor_id, apple_audio_asset_vendor_id) do
          assert_equal SyncLog.apple.podcast_containers.count, 0
          assert_equal Apple::PodcastContainer.count, 0

          Apple::PodcastContainer.upsert_podcast_container(apple_episode,
            podcast_container_json_row)
          assert_equal SyncLog.apple.podcast_containers.count, 1
          assert_equal Apple::PodcastContainer.count, 1

          Apple::PodcastContainer.upsert_podcast_container(apple_episode,
            podcast_container_json_row)

          # The second call should not create a new log or podcast container
          assert_equal SyncLog.apple.podcast_containers.count, 1
          assert_equal Apple::PodcastContainer.count, 1
        end
      end
    end

    it "should reload the feeder episodes apple_podcast_container attribute" do
      apple_episode.stub(:apple_id, apple_episode_id) do
        apple_episode.stub(:audio_asset_vendor_id, apple_audio_asset_vendor_id) do
          # show that the call to upsert_podcast_container will reload the
          # feeder episode's apple_podcast_container attribute

          # Set the apple_podcast_container to a value that is not the pc1 result
          apple_episode.feeder_episode.build_apple_podcast_container(vendor_id: "not this one!")
          assert_equal "not this one!", apple_episode.podcast_container.vendor_id

          Apple::PodcastContainer.upsert_podcast_container(apple_episode,
            podcast_container_json_row)
          # The apple_podcast_container should be reloaded
          # it reflects the stubbed apple_audio_assed_vendor_id, now upserted as a col in pc1
          assert_equal "apple-vendor-id", apple_episode.podcast_container.vendor_id
        end
      end
    end

    it "should update timestamps when upserting" do
      apple_episode.stub(:apple_id, apple_episode_id) do
        apple_episode.stub(:audio_asset_vendor_id, apple_audio_asset_vendor_id) do
          pc1 = Apple::PodcastContainer.upsert_podcast_container(apple_episode,
            podcast_container_json_row)

          pc1.update(updated_at: Time.now - 1.year)
          # upsert
          pc2 = Apple::PodcastContainer.upsert_podcast_container(apple_episode,
            podcast_container_json_row.merge({foo: "bar"}))

          assert pc1 == pc2
          assert pc2.updated_at > pc1.updated_at
        end
      end
    end

    it "should not update the source_url and source_file_name" do
      apple_episode.stub(:apple_id, apple_episode_id) do
        apple_episode.stub(:audio_asset_vendor_id, apple_audio_asset_vendor_id) do
          status = episode.apple_status

          # It does not touch the source_url or source_filename on create
          Apple::PodcastContainer.upsert_podcast_container(apple_episode,
            podcast_container_json_row)
          assert_nil status&.enclosure_url
          assert_nil status&.source_url
          assert_nil status&.source_filename

          Apple::PodcastContainer.upsert_podcast_container(apple_episode,
            podcast_container_json_row)

          # It does not touch the source_url or source_filename on update
          assert_nil status&.enclosure_url
          assert_nil status&.source_url
          assert_nil status&.source_filename
        end
      end
    end
  end

  describe ".poll_podcast_container_state(api, episodes)" do
    it "creates new records if they dont exist" do
      assert_equal SyncLog.apple.podcast_containers.count, 0

      Apple::PodcastContainer.stub(:get_podcast_containers_via_episodes, [podcast_container_json_row]) do
        apple_episode.stub(:apple_id, apple_episode_id) do
          apple_episode.stub(:apple_persisted?, true) do
            apple_episode.stub(:audio_asset_vendor_id, apple_audio_asset_vendor_id) do
              Apple::PodcastContainer.poll_podcast_container_state(nil, [apple_episode])
            end
          end
        end
      end
      assert_equal SyncLog.apple.podcast_containers.count, 1
    end
  end

  describe "#podcast_deliveries" do
    let(:container) { Apple::PodcastContainer.new }
    it "should have many deliveries" do
      assert_equal [], container.podcast_deliveries
      pd = container.podcast_deliveries.build
      assert_equal Apple::PodcastDelivery, pd.class
    end
  end

  describe ".get_podcast_containers_bridge_params" do
    it "should set the apple episode id in the request metadata" do
      apple_episode.stub(:audio_asset_vendor_id, "some-vendor-id") do
        apple_episode.stub(:apple_id, "ap-ep-id") do
          res = Apple::PodcastContainer.get_podcast_containers_bridge_params(api, [apple_episode])
          bridge_param = res.first
          assert_equal bridge_param[:request_metadata].fetch(:apple_episode_id), apple_episode.apple_id
        end
      end
    end
  end

  describe ".podcast_container_url" do
    it "raises an error if the vendor id is missing" do
      assert_raises(RuntimeError, "incomplete api response") do
        Apple::PodcastContainer.podcast_container_url(api, OpenStruct.new)
      end
    end
  end

  describe "#has_podcast_audio?" do
    let(:file) do
      {"fileName" => "SomeName.flac",
       "fileType" => "audio",
       "status" => "In Asset Repository",
       "assetRole" => "PodcastSourceAudio"}
    end

    let(:container) { Apple::PodcastContainer.new }

    it "returns true if the podcast container has a podcast audio file" do
      container.stub(:apple_attributes, {"files" => [file]}) do
        assert container.has_podcast_audio?
      end
    end

    it "returns false if the status is not in asset repository" do
      file["status"] = "Not In Asset Repository"
      container.stub(:apple_attributes, {"files" => [file]}) do
        refute container.has_podcast_audio?
      end
    end

    it "returns false if the assetRole is not podcast source audio" do
      file["assetRole"] = "Not Podcast Source Audio"
      container.stub(:apple_attributes, {"files" => [file]}) do
        refute container.has_podcast_audio?
      end
    end
  end

  describe "retry sentinals and gatekeeping" do
    let(:container) { Apple::PodcastContainer.new }
    describe "#delivery_settled?" do
      it "should be settled if there are no delivery files" do
        container.stub(:podcast_delivery_files, []) do
          assert container.delivery_settled?
          assert container.delivered?
        end
      end
    end

    describe "#container_upload_satisfied?" do
      it "should be satisfied with podcast files and a settled delivery" do
        container.stub(:files, [
          {status: Apple::PodcastContainer::FILE_STATUS_SUCCESS,
           assetRole: Apple::PodcastContainer::FILE_ASSET_ROLE_PODCAST_AUDIO}.with_indifferent_access
        ]) do
          assert container.container_upload_satisfied?
        end
      end
    end
  end

  describe "#destroy" do
    it "should destroy the podcast container and cascade to the delivery and delivery file" do
      apple_episode.stub(:apple_id, apple_episode_id) do
        apple_episode.stub(:audio_asset_vendor_id, apple_audio_asset_vendor_id) do
          pc = Apple::PodcastContainer.upsert_podcast_container(apple_episode, podcast_container_json_row)
          pd = pc.podcast_deliveries.create!(episode: pc.episode)
          pdf = pd.podcast_delivery_files.create!(episode: pc.episode)

          pc.podcast_deliveries.destroy_all
          pc.podcast_delivery_files.destroy_all

          assert_not_nil pd.reload.deleted_at
          assert_not_nil pdf.reload.deleted_at
        end
      end
    end
  end
end
