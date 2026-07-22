# frozen_string_literal: true

require "test_helper"

describe Apple::Episode do
  let(:podcast) { create(:podcast) }

  let(:public_feed) { podcast.default_feed }
  let(:private_feed) { create(:private_feed, podcast: podcast) }

  let(:apple_config) { build(:apple_config) }
  let(:apple_api) { Apple::Api.from_apple_config(apple_config) }

  let(:episode) { create(:episode, podcast: podcast) }
  let(:apple_show) do
    Apple::Show.new(api: apple_api,
      public_feed: public_feed,
      private_feed: private_feed)
  end
  let(:apple_episode) { build(:apple_episode, show: apple_show, feeder_episode: episode, create_sync_log: false) }
  let(:apple_episode_api_response) { build(:apple_episode_api_response, apple_episode_id: "123") }
  let(:external_id) { apple_episode_api_response["api_response"]["api_response"]["val"]["data"]["id"] }

  before do
    create_legacy_apple_episode_sync_log(episode, external_id: external_id, **apple_episode_api_response)
    SyncLog.log!(integration: :apple, feeder_type: :feeds, feeder_id: public_feed.id, external_id: "show-1")
  end

  describe ".upsert_sync_log" do
    it "stamps the apple show id" do
      response = build(:apple_episode_api_response)["api_response"]

      sync_log = Apple::Episode.upsert_sync_log(apple_episode, response)

      assert_equal "show-1", sync_log.reload.apple_show_id
    end
  end

  describe "#sync_log" do
    it "returns the scoped row for the current show" do
      scoped = apple_sync_log_for(episode)
      scoped.update!(external_id: "scoped-ep", apple_show_id: "show-1")

      assert_equal scoped, apple_episode.sync_log
    end

    it "falls back to a legacy row when a scoped row does not exist" do
      legacy = apple_sync_log_for(episode)

      assert_equal legacy, apple_episode.sync_log
    end

    it "keeps sync-log reads within the current show" do
      show_one_log = apple_sync_log_for(episode)
      show_one_log.update!(external_id: "show-one-episode", apple_show_id: "show-1")
      show_two_log = SyncLog.create!(
        integration: :apple,
        feeder_type: :episodes,
        feeder_id: episode.id,
        external_id: "show-two-episode",
        apple_show_id: "show-2"
      )

      assert_equal show_one_log, apple_episode_for_show("show-1").sync_log
      assert_equal show_two_log, apple_episode_for_show("show-2").sync_log
    end
  end

  describe "show-scoped delivery state" do
    let(:show_one_episode) do
      build(:apple_episode, show: apple_show, feeder_episode: episode).tap do |apple_episode|
        apple_episode.define_singleton_method(:apple_show_id) { "show-1" }
      end
    end
    let(:show_two_episode) do
      build(:apple_episode, show: apple_show, feeder_episode: episode).tap do |apple_episode|
        apple_episode.define_singleton_method(:apple_show_id) { "show-2" }
      end
    end

    it "rejects new delivery status rows without a show id" do
      status = build(:apple_episode_delivery_status, episode: episode, apple_show_id: nil)

      refute status.valid?
      assert_includes status.errors[:apple_show_id], "Can't be blank"
    end

    it "does not expose the generic instance update path" do
      status = create(:apple_episode_delivery_status, episode: episode, apple_show_id: "show-1")

      assert_raises(NoMethodError) { status.send(:update_status, delivered: true) }
    end

    it "lets a known show read legacy status and stamps the next write" do
      legacy_status = create_legacy_record(:apple_episode_delivery_status,
        episode: episode,
        apple_show_id: nil,
        delivered: false,
        uploaded: false,
        asset_processing_attempts: 2)

      assert_equal legacy_status, show_one_episode.delivery_status
      assert_includes show_one_episode.delivery_statuses, legacy_status

      scoped_status = show_one_episode.update_delivery_status(uploaded: true)

      refute_equal legacy_status, scoped_status
      assert_equal "show-1", scoped_status.apple_show_id
      assert scoped_status.uploaded
      assert_equal 2, scoped_status.asset_processing_attempts
      assert_nil legacy_status.reload.apple_show_id
      refute legacy_status.uploaded
    end

    it "allows an existing legacy status to remain saveable during backfill" do
      legacy_status = create_legacy_record(:apple_episode_delivery_status,
        episode: episode,
        apple_show_id: nil,
        delivered: false)

      legacy_status.update!(source_fetch_count: 1)

      assert_equal 1, legacy_status.reload.source_fetch_count
      assert_nil legacy_status.apple_show_id
    end

    it "keeps delivery-status reads and writes within the current show" do
      legacy_status = create_legacy_record(:apple_episode_delivery_status,
        episode: episode,
        apple_show_id: nil,
        delivered: false)

      show_one_episode.update_delivery_status(delivered: true)
      show_two_episode.update_delivery_status(delivered: false, uploaded: true)

      assert show_one_episode.delivery_status.delivered
      refute show_two_episode.delivery_status.delivered
      assert show_two_episode.delivery_status.uploaded
      assert_equal "show-1", show_one_episode.delivery_status.apple_show_id
      assert_equal "show-2", show_two_episode.delivery_status.apple_show_id
      assert_nil legacy_status.reload.apple_show_id

      show_one_episode.update_delivery_status(uploaded: false)

      refute show_one_episode.delivery_status.uploaded
      assert show_two_episode.delivery_status.uploaded
    end

    it "does not read another show's container or deliveries" do
      container = create(:apple_podcast_container,
        episode: episode,
        apple_show_id: "show-1")
      delivery = create(:apple_podcast_delivery,
        episode: episode,
        podcast_container: container)

      assert_equal container, show_one_episode.podcast_container
      assert_equal [delivery], show_one_episode.podcast_deliveries.to_a
      assert_nil show_two_episode.podcast_container
      assert_empty show_two_episode.podcast_deliveries
    end

    it "allows a known show to read its legacy container" do
      legacy_container = create_legacy_record(:apple_podcast_container,
        episode: episode,
        apple_show_id: nil)

      assert_equal legacy_container, show_one_episode.podcast_container
    end

    it "rejects delivery-state access without a show id" do
      showless_episode = build(:apple_episode, show: apple_show, feeder_episode: episode)
      showless_episode.define_singleton_method(:apple_show_id) { nil }
      legacy_container = create_legacy_record(:apple_podcast_container, episode: episode, apple_show_id: nil)
      legacy_status = create_legacy_record(:apple_episode_delivery_status,
        episode: episode,
        apple_show_id: nil,
        delivered: false)

      assert_raises(ArgumentError) { showless_episode.podcast_container }
      assert_raises(ArgumentError) { showless_episode.sync_log }
      assert_raises(ArgumentError) { showless_episode.delivery_status }
      assert_raises(ArgumentError) { showless_episode.delivery_statuses.to_a }
      assert_raises(ArgumentError) { showless_episode.update_delivery_status(delivered: true) }

      assert_equal legacy_container, Apple::PodcastContainer.find(legacy_container.id)
      refute legacy_status.reload.delivered
      assert_nil legacy_status.apple_show_id
      assert_equal 1, Apple::EpisodeDeliveryStatus.where(episode_id: episode.id).count
    end

    it "exposes only the explicit show-scoped API" do
      assert_equal episode.media_version_id, show_one_episode.media_version_id
      assert_equal episode.podcast_id, show_one_episode.podcast_id

      undelegated_methods = {
        apple_prepare_for_delivery!: [],
        apple_podcast_container: [],
        apple_podcast_containers: [],
        build_initial_delivery_status: [],
        delete_episode_delivery_status: [:apple],
        episode_delivery_status: [:apple],
        episode_delivery_statuses: [],
        sync_logs: [],
        title: [],
        update_episode_delivery_status: [:apple, {delivered: true}]
      }

      undelegated_methods.each do |method_name, arguments|
        refute show_one_episode.respond_to?(method_name), method_name
        assert_raises(NoMethodError, method_name) do
          show_one_episode.public_send(method_name, *arguments)
        end
      end
    end
  end

  describe "#apple_json" do
    let(:apple_episode_list) do
      [
        apple_episode_json
      ]
    end

    it "instantiates with an api_response" do
      ep = build(:apple_episode, show: apple_show, feeder_episode: episode)

      assert_equal "123", ep.apple_id
      assert_equal "456", ep.audio_asset_vendor_id
      assert_equal true, ep.drafting?, true
      assert_equal episode.item_guid, ep.guid
    end

    it "instantiates with a nil api_response" do
      ep = build(:apple_episode, show: apple_show, feeder_episode: episode, create_sync_log: false)
      apple_sync_log_for(ep.feeder_episode).destroy
      ep.feeder_episode.reload

      assert_nil ep.apple_id
      assert_raises(RuntimeError, "incomplete api response") { ep.audio_asset_vendor_id }
      # It does not exists yet, so it is not drafting
      assert_equal false, ep.drafting?
      # Comes from the feeder model
      assert_equal episode.item_guid, ep.guid
    end
  end

  describe "#enclosure_url" do
    it "should add auth query param" do
      assert_match(/auth=/, apple_episode.enclosure_url)
    end
  end

  describe "#waiting_for_asset_state?" do
    let(:container) { create(:apple_podcast_container, episode: episode, apple_episode_id: "123") }

    let(:delivery) do
      pd = Apple::PodcastDelivery.new(episode: episode, podcast_container: container)
      pd.save!
      pd
    end

    let(:delivery_file) do
      pdf = Apple::PodcastDeliveryFile.new(episode: episode, podcast_delivery: delivery)
      pdf.update(apple_sync_log: SyncLog.new(**build(:podcast_delivery_file_api_response).merge(external_id: "123"), feeder_type: :podcast_delivery_files, integration: :apple))
      pdf.save!
      pdf
    end

    before do
      assert_equal [delivery_file], apple_episode.podcast_delivery_files
    end

    it "should be true if all the conditions are met" do
      assert_equal true, apple_episode.waiting_for_asset_state?
    end

    it "should be true if there are no podcast delivery files and the asset state is UNSPECIFIED" do
      apple_episode.podcast_container.stub(:podcast_delivery_files, []) do
        assert_equal true, apple_episode.waiting_for_asset_state?
      end
    end

    it "should be false if the delivery file is not delivered" do
      delivery_file.apple_sync_log.update!(**build(:podcast_delivery_file_api_response, asset_delivery_state: "AWAITING_UPLOAD"))
      apple_episode.podcast_delivery_files.reset

      assert_equal false, apple_episode.waiting_for_asset_state?
    end

    it "should be false if the delivery file has asset processing errors" do
      delivery_file.apple_sync_log.update!(**build(:podcast_delivery_file_api_response, asset_processing_state: "VALIDATION_FAILED"))
      apple_episode.podcast_delivery_files.reset

      assert_equal false, apple_episode.waiting_for_asset_state?
    end

    it "should be false if the delivery file has errors" do
      delivery_file.apple_sync_log.update!(**build(:podcast_delivery_file_api_response, asset_processing_state: "VALIDATION_FAILED"))
      apple_episode.podcast_delivery_files.reset

      assert_equal false, apple_episode.waiting_for_asset_state?
    end

    it "should be false if the episode has a non complete apple hosted audio asset state" do
      sync_log = apple_episode.sync_log
      sync_log.api_response["api_response"]["val"]["data"]["attributes"]["appleHostedAudioAssetState"] = Apple::Episode::AUDIO_ASSET_FAILURE
      sync_log.update_column(:api_response, sync_log.api_response)

      delivery_file.apple_sync_log.update!(**build(:podcast_delivery_file_api_response).merge(external_id: "123"))
      apple_episode.podcast_delivery_files.reset

      assert_equal false, apple_episode.waiting_for_asset_state?
    end
  end

  describe "#episode_update_parameters" do
    it "should mirror the create params with the addition of the id" do
      apple_episode.stub(:apple_id, "123") do
        assert_equal "123", apple_episode.episode_update_parameters[:data][:id]
      end
    end
  end

  describe ".update_episodes" do
    it "ignores 409 errors for some episodes" do
      SyncLog.log!(integration: :apple, feeder_type: :feeds, feeder_id: public_feed.id, external_id: "show-1")
      episode1 = create(:episode, podcast: podcast)
      episode2 = create(:episode, podcast: podcast)
      apple_episode1 = build(:apple_episode, show: apple_show, feeder_episode: episode1)
      apple_episode2 = build(:apple_episode, show: apple_show, feeder_episode: episode2)

      # Mock the bridge_remote_and_retry method to return a mix of successful and 409 error responses
      mock_response = [
        {
          "api_response" => {
            "ok" => true,
            "err" => false,
            "val" => {"data" => {"id" => "123", "type" => "episodes"}}
          },
          "request_metadata" => {"apple_episode_id" => "123", "guid" => episode1.item_guid}
        },
        {
          "api_response" => {
            "ok" => false,
            "err" => true,
            "val" => {"data" => {"status" => "409", "title" => "Conflict"}}
          },
          "request_metadata" => {"apple_episode_id" => "456", "guid" => episode2.item_guid}
        }
      ]

      apple_api.stub :bridge_remote, OpenStruct.new(code: "200", body: mock_response.to_json) do
        apple_sync_log_for(apple_episode2.feeder_episode).destroy
        apple_episode2.feeder_episode.reload

        updated_episodes = Apple::Episode.update_episodes(apple_api, [apple_episode1, apple_episode2])

        assert_equal 1, updated_episodes.length, "Expected one successfully updated episode"
        assert_equal "123", updated_episodes.first.external_id, "Expected the successful episode to be updated"

        # Verify that the 409 error was ignored and didn't cause the method to raise an error
        apple_episode2.feeder_episode.reload
        assert_nil apple_sync_log_for(apple_episode2.feeder_episode), "Expected no sync log update for the episode with 409 error"
      end
    end
  end

  describe "#needs_media_version?" do
    let(:audio_version_id) {
    }
    it "should be true if the delivery status is nil or has nil attrs" do
      assert apple_episode.delivery_statuses.destroy_all
      assert apple_episode.delivery_status.source_media_version_id.nil?

      assert_equal true, apple_episode.needs_media_version?
    end

    it "should be true if the delivery status indicates another media version" do
      create(:content, episode: apple_episode.feeder_episode, position: 1, status: "complete")
      create(:content, episode: apple_episode.feeder_episode, position: 2, status: "complete")
      mid = apple_episode.feeder_episode.reload.cut_media_version!

      apple_episode.update_delivery_status(delivered: true, source_media_version_id: mid.id)
      refute apple_episode.needs_media_version?

      apple_episode.update_delivery_status(source_media_version_id: -1)

      assert apple_episode.needs_media_version?
    end
  end

  describe "#synced_with_apple?" do
    let(:apple_episode_api_response) { build(:apple_episode_api_response, publishing_state: "PUBLISH") }

    it "should be false when drafting" do
      ep = build(:uploaded_apple_episode, show: apple_show)
      assert_equal true, ep.synced_with_apple?

      ep.stub(:drafting?, true) do
        assert_equal false, ep.synced_with_apple?
      end
    end

    it "should be false when the podcast_container is nil" do
      ep = build(:apple_episode, show: apple_show)
      assert ep.podcast_container.nil?

      # it returns early via the guard
      ep.stub(:podcast_container, -> { raise "shouldn't happen" }) do
        ep.stub(:has_container?, false) do
          refute ep.container_upload_complete?
        end
      end
    end
  end

  describe "#enclosure_filename" do
    let(:episode) { create(:episode_with_media, podcast: podcast) }

    it "should return the filename from the enclosure url" do
      assert_equal "audio.flac", apple_episode.enclosure_filename
    end

    it "uses the private feed enclosure" do
      private_feed.enclosure_template = "http://foo.bar/any/where/whatev{feed_extension}"
      assert_equal "whatev.flac", apple_episode.enclosure_filename
    end
  end

  describe "#publish" do
    it "should call poll! at the conclusion of the episode publishing" do
      mock = Minitest::Mock.new
      mock.expect(:call, [], [apple_api, apple_show, [apple_episode]])

      apple_api.stub(:bridge_remote_and_retry!, [{
        request_metadata: {
          apple_episode_id: apple_episode.apple_id,
          guid: apple_episode.guid
        },
        api_url: "asdf/",
        api_parameters: "ARBITRARY"
      }.with_indifferent_access]) do
        Apple::Episode.stub(:poll_episode_state, mock) do
          Apple::Episode.publish(apple_api, apple_show, [apple_episode])
        end
      end

      assert mock.verify
    end
  end

  describe "#archive" do
    it "should delegate to the alter_publish_state" do
      mock = Minitest::Mock.new
      mock.expect(:call, [], [apple_api, apple_show, [apple_episode], "ARCHIVE"])

      apple_api.stub(:bridge_remote_and_retry, nil) do
        Apple::Episode.stub(:alter_publish_state, mock) do
          Apple::Episode.archive(apple_api, apple_show, [apple_episode])
        end
      end

      assert mock.verify
    end
  end

  describe ".prepare_for_delivery" do
    it "should filter for episodes that need delivery" do
      assert_equal [apple_episode], Apple::Episode.prepare_for_delivery([apple_episode])
    end

    describe "soft deleting the delivery files" do
      let(:container) { create(:apple_podcast_container, episode: episode, apple_episode_id: "123") }

      let(:delivery) do
        pd = Apple::PodcastDelivery.new(episode: episode, podcast_container: container)
        pd.save!
        pd
      end

      let(:delivery_file) do
        pdf = Apple::PodcastDeliveryFile.new(episode: episode, podcast_delivery: delivery)
        pdf.update(apple_sync_log: SyncLog.new(**build(:podcast_delivery_file_api_response).merge(external_id: "123"), feeder_type: :podcast_delivery_files, integration: :apple))
        pdf.save!
        pdf
      end

      before do
        assert_equal [delivery_file], apple_episode.podcast_delivery_files
      end

      it "should delete the delivery files" do
        assert apple_episode.podcast_delivery_files.length == 1

        apple_episode.stub(:needs_delivery?, true) do
          assert_equal [apple_episode], Apple::Episode.prepare_for_delivery([apple_episode])
        end

        assert apple_episode.podcast_delivery_files.length == 0
      end
    end
  end

  describe ".probe_asset_state" do
    let(:episode1) { create(:episode, podcast: podcast) }
    let(:episode2) { create(:episode, podcast: podcast) }
    let(:container1) { create(:apple_podcast_container, episode: episode1, apple_episode_id: "ep1") }
    let(:container2) { create(:apple_podcast_container, episode: episode2, apple_episode_id: "ep2") }

    let(:apple_episode1) { build(:apple_episode, show: apple_show, feeder_episode: episode1, create_sync_log: false) }
    let(:apple_episode2) { build(:apple_episode, show: apple_show, feeder_episode: episode2, create_sync_log: false) }

    it "partitions episodes into ready and waiting sets" do
      SyncLog.log!(integration: :apple, feeder_type: :feeds, feeder_id: public_feed.id, external_id: "show-1")
      # Create sync logs for both episodes
      create_legacy_apple_episode_sync_log(episode1, external_id: "ep1", **build(:apple_episode_api_response, item_guid: episode1.item_guid))
      create_legacy_apple_episode_sync_log(episode2, external_id: "ep2", **build(:apple_episode_api_response, item_guid: episode2.item_guid, apple_hosted_audio_state: Apple::Episode::AUDIO_ASSET_SUCCESS))

      # Setup episode1 to be waiting (delivery settled, asset state not finished)
      delivery1 = create(:apple_podcast_delivery, episode: episode1, podcast_container: container1)
      create(:apple_podcast_delivery_file,
        delivery: delivery1,
        episode: episode1,
        api_marked_as_uploaded: true,
        upload_operations_complete: true)

      # Setup episode2 with finished asset state (SUCCESS)
      delivery2 = create(:apple_podcast_delivery, episode: episode2, podcast_container: container2)
      create(:apple_podcast_delivery_file,
        delivery: delivery2,
        episode: episode2,
        api_marked_as_uploaded: true,
        upload_operations_complete: true)

      mock_responses = [
        {
          "request_metadata" => {"feeder_id" => episode1.id},
          "api_response" => {
            "ok" => true,
            "val" => {
              "data" => {
                "id" => "ep1",
                "attributes" => {"appleHostedAudioAssetState" => "UNSPECIFIED"}
              }
            }
          }
        },
        {
          "request_metadata" => {"feeder_id" => episode2.id},
          "api_response" => {
            "ok" => true,
            "val" => {
              "data" => {
                "id" => "ep2",
                "attributes" => {"appleHostedAudioAssetState" => Apple::Episode::AUDIO_ASSET_SUCCESS}
              }
            }
          }
        }
      ]

      Apple::Episode.stub(:get_episodes, mock_responses) do
        (ready, waiting) = Apple::Episode.probe_asset_state(apple_api, [apple_episode1, apple_episode2])

        assert_equal 1, waiting.length, "Expected one episode waiting"
        assert_equal episode1.id, waiting.first.feeder_id, "Expected episode1 to be waiting"

        assert_equal 1, ready.length, "Expected one episode ready"
        assert_equal episode2.id, ready.first.feeder_id, "Expected episode2 to be ready"
      end
    end

    it "returns empty arrays when no episodes provided" do
      Apple::Episode.stub(:get_episodes, []) do
        (ready, waiting) = Apple::Episode.probe_asset_state(apple_api, [])

        assert_equal 0, ready.length
        assert_equal 0, waiting.length
      end
    end
  end

  def create_legacy_apple_episode_sync_log(episode, **attrs)
    sync_log = SyncLog.new(attrs.merge(
      integration: :apple,
      feeder_type: :episodes,
      feeder_id: episode.id
    ))
    sync_log.save!(validate: false)
    sync_log
  end

  def apple_sync_log_for(episode)
    SyncLog.apple.episodes.find_by(feeder_id: episode.id)
  end

  def apple_episode_for_show(apple_show_id)
    Apple::Episode.new(show: apple_show, feeder_episode: episode, api: apple_api).tap do |facade|
      facade.define_singleton_method(:apple_show_id) { apple_show_id }
    end
  end

  def create_legacy_record(factory_name, **attributes)
    record = build(factory_name, **attributes)
    record.save!(validate: false)
    record
  end
end
