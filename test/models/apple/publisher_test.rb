require "test_helper"

describe Apple::Publisher do
  let(:podcast) { create(:podcast) }
  let(:public_feed) { podcast.default_feed }
  let(:private_feed) { create(:feed, podcast: podcast, private: true) }
  let(:apple_config) { build(:apple_config) }
  let(:apple_api) { Apple::Api.from_apple_config(apple_config) }

  let(:apple_publisher) do
    Apple::Publisher.new(api: apple_api, public_feed: public_feed, private_feed: private_feed)
  end

  let(:publisher) { apple_publisher }

  before do
    stub_request(:get, "https://api.podcastsconnect.apple.com/v1/countriesAndRegions?limit=200")
      .to_return(status: 200, body: json_file(:apple_countries_and_regions), headers: {})

    public_feed.save!
  end

  describe ".initialize" do
    it "should build a publisher with the correct feeds" do
      assert_equal apple_publisher.public_feed, public_feed
      assert_equal apple_publisher.private_feed, private_feed
    end
  end

  describe "#show" do
    it "should be initialized with the publishers api reference" do
      assert_equal apple_publisher.show.api.object_id, apple_api.object_id
    end
  end

  describe "#only_episodes_with_apple_state" do
    let(:episode) { build(:apple_episode) }

    it "should only return episodes that have an apple state" do
      episode.stub(:apple_new?, true) do
        assert_equal apple_publisher.only_episodes_with_integration_state([episode]), []
      end
      episode.stub(:apple_new?, false) do
        assert_equal apple_publisher.only_episodes_with_integration_state([episode]), [episode]
      end
    end
  end

  describe "#filter_episodes_to_sync" do
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
    let(:apple_episode) { build(:apple_episode, show: apple_show, feeder_episode: episode) }
    let(:apple_episode_api_response) { build(:apple_episode_api_response, apple_episode_id: "123") }
    let(:external_id) { apple_episode_api_response["api_response"]["api_response"]["val"]["data"]["id"] }

    before do
      episode.create_apple_sync_log(external_id: external_id, **apple_episode_api_response)
    end

    it "should filter episodes that are already synced to apple" do
      refute apple_episode.video_content_type?

      apple_episode.stub(:synced_with_apple?, true) do
        assert_equal [], apple_publisher.filter_episodes_to_sync([apple_episode])
      end

      apple_episode.stub(:synced_with_apple?, false) do
        assert_equal [apple_episode], apple_publisher.filter_episodes_to_sync([apple_episode])
      end
    end

    it "should filter episodes that have a video mime" do
      apple_episode.stub(:synced_with_apple?, false) do
        apple_episode.stub(:video_content_type?, true) do
          assert_equal [], apple_publisher.filter_episodes_to_sync([apple_episode])
        end
      end

      apple_episode.stub(:synced_with_apple?, false) do
        apple_episode.stub(:video_content_type?, false) do
          assert_equal [apple_episode], apple_publisher.filter_episodes_to_sync([apple_episode])
        end
      end
    end
  end

  describe "#sync_episodes!" do
    it "should create new episodes" do
      apple_publisher.stub(:poll_episodes!, []) do
        new_ep = OpenStruct.new(drafting?: false, apple_new?: true)
        mock = Minitest::Mock.new
        mock.expect(:call, [], [apple_publisher.api, [new_ep]])
        Apple::Episode.stub(:create_episodes, mock) do
          apple_publisher.sync_episodes!([new_ep])
        end
        assert mock.verify
      end
    end

    it "should update draft episodes" do
      apple_publisher.stub(:poll_episodes!, []) do
        draft_ep = OpenStruct.new(drafting?: true, apple_new?: false)
        mock = Minitest::Mock.new
        mock.expect(:call, [], [apple_publisher.api, [draft_ep]])
        Apple::Episode.stub(:update_episodes, mock) do
          apple_publisher.sync_episodes!([draft_ep])
        end
        assert mock.verify
      end
    end
  end

  describe "Archive and Unarchive flows" do
    let(:podcast) { create(:podcast) }
    let(:public_feed) { podcast.default_feed }
    let(:private_feed) { create(:private_feed, podcast: podcast) }
    let(:apple_config) { create(:apple_config, feed: private_feed) }
    let(:episode) { create(:episode, podcast: podcast) }
    let(:apple_episode_api_response) { build(:apple_episode_api_response, apple_episode_id: "123") }
    let(:apple_publisher) { apple_config.build_publisher }
    let(:apple_api) { apple_publisher.api }
    let(:apple_episode) { Apple::Episode.new(show: apple_publisher.show, feeder_episode: episode, api: apple_api) }

    before do
      Apple::Show.connect_existing("123", apple_config)
      episode.create_apple_sync_log(external_id: "123", **apple_episode_api_response)
      private_feed.episodes << episode
    end

    describe "#episodes_to_archive" do
      it "should select episodes that are not in the private feed" do
        # it's in the feed
        assert_equal [episode], private_feed.feed_episodes
        # so no archive
        assert_equal [], apple_publisher.episodes_to_archive

        private_feed.episodes.delete(episode)
        apple_publisher.show.reload

        # it's not in the feed
        assert_equal [], private_feed.feed_episodes
        assert_equal [apple_episode.feeder_id], apple_publisher.episodes_to_archive.map(&:feeder_id)
      end

      it "should archive episodes that are deleted" do
        # destroy it from the feed
        apple_episode.feeder_episode.destroy
        assert_equal [], private_feed.feed_episodes
        apple_publisher.show.reload

        # it's deleted, but still in the list of podcast epiodes
        assert_equal [apple_episode.feeder_id], apple_publisher.show.podcast_episodes.map(&:feeder_id)

        assert_equal [apple_episode.feeder_id], apple_publisher.episodes_to_archive.map(&:feeder_id)
      end

      it "should reject episodes that don't have apple state" do
        # Remove the apple state to model a un-synced episode
        apple_episode.sync_log.destroy!
        apple_episode.feeder_episode.destroy
        assert_equal [], private_feed.feed_episodes
        apple_publisher.show.reload

        # it's deleted, but still in the list of podcast epiodes
        assert_equal [apple_episode.feeder_id], apple_publisher.show.podcast_episodes.map(&:feeder_id)
        apple_episode = apple_publisher.show.podcast_episodes.first

        # lacks apple state
        assert apple_episode.apple_new?

        assert_equal [], apple_publisher.episodes_to_archive
      end

      describe "archived episodes" do
        let(:apple_episode_api_response) { build(:apple_episode_api_response, publishing_state: "ARCHIVED", apple_episode_id: "123") }

        it "should reject episodes that are already archived" do
          # Typical case where the episode is deleted and will be archived
          apple_episode.feeder_episode.destroy
          assert_equal [], private_feed.feed_episodes
          apple_publisher.show.reload
          # reload the episode
          apple_episode = apple_publisher.show.podcast_episodes.first
          # pointer equals
          assert_equal [apple_episode.object_id], apple_publisher.show.podcast_episodes.map(&:object_id)

          assert apple_episode.archived?

          assert_equal [], apple_publisher.episodes_to_archive
        end

        it "should dynamically calculate which episodes are archived" do
          # In the case where we have some existing episodes to archive and then poll the episode endpoint
          # and find that the episode is already archived.
          sync_log = apple_episode.sync_log
          res = sync_log.api_response
          res["api_response"]["val"]["data"]["attributes"]["publishingState"] = "PUBLISHED"
          apple_episode.feeder_episode.apple_sync_log.update!(api_response: res)

          assert_equal "PUBLISHED", apple_episode.publishing_state

          # model the case where the episode is destroyed, triggering an archive
          apple_episode.feeder_episode.destroy
          assert_equal [], private_feed.feed_episodes
          apple_publisher.show.reload
          apple_episode = apple_publisher.show.podcast_episodes.first
          assert_equal [apple_episode.object_id], apple_publisher.show.podcast_episodes.map(&:object_id)

          refute apple_episode.archived?
          assert_equal [apple_episode], apple_publisher.episodes_to_archive

          res["api_response"]["val"]["data"]["attributes"]["publishingState"] = "ARCHIVED"
          apple_episode.feeder_episode.apple_sync_log.update!(api_response: res)

          assert apple_episode.archived?
          assert_equal [], apple_publisher.episodes_to_archive
        end
      end

      it "should archive an upublished episode" do
        apple_episode.feeder_episode.update!(published_at: nil, released_at: nil)
        refute apple_episode.feeder_episode.published?

        assert_equal [], private_feed.feed_episodes
        apple_publisher.show.reload
        # reload the episode
        apple_episode = apple_publisher.show.podcast_episodes.first

        assert_equal [apple_episode], apple_publisher.episodes_to_archive
      end
    end

    describe "#episode_to_unarchive" do
      let(:apple_episode_api_response) { build(:apple_episode_api_response, publishing_state: "ARCHIVED", apple_episode_id: "123") }

      it "should select episodes that are in the private feed" do
        assert_equal [episode], private_feed.feed_episodes
        # episodes to sync includes the archived episode
        assert_equal [apple_episode.feeder_id], apple_publisher.episodes_to_sync.map(&:feeder_id)
        assert_equal [apple_episode.feeder_id], apple_publisher.episodes_to_unarchive.map(&:feeder_id)
      end

      describe "non-archived episodes" do
        let(:apple_episode_api_response) { build(:apple_episode_api_response, publishing_state: "DRAFTING", apple_episode_id: "123") }

        it "should not select the episode" do
          assert_equal [episode], private_feed.feed_episodes
          assert_equal [apple_episode.feeder_id], apple_publisher.episodes_to_sync.map(&:feeder_id)

          # does not un-archive the episode
          assert_equal [], apple_publisher.episodes_to_unarchive.map(&:feeder_id)
        end
      end

      describe "archived episodes with media already delivered to apple" do
        let(:apple_episode_api_response) {
          build(:apple_episode_api_response,
            apple_hosted_audio_state: Apple::Episode::AUDIO_ASSET_SUCCESS,
            publishing_state: "ARCHIVED",
            apple_episode_id: "123")
        }

        let(:apple_episode) { build(:uploaded_apple_episode, show: apple_publisher.show, feeder_episode: episode, api: apple_api) }

        it "includes the unarchived episode in the episodes to sync" do
          assert apple_episode.audio_asset_state_success?
          assert apple_episode.archived?
          assert apple_episode.has_delivery?

          assert_equal [apple_episode.feeder_id], apple_publisher.episodes_to_unarchive.map(&:feeder_id)
          # we can't sync archived episodes
          assert_equal [], apple_publisher.episodes_to_sync.map(&:feeder_id)

          unarchiver = ->(eps) do
            eps.map do |ep|
              sl = ep.apple_sync_log
              attrs = sl.api_response
              attrs["api_response"]["val"]["data"]["attributes"]["publishingState"] = "DRAFTING"
              sl.update!(api_response: attrs)
              sl
            end
          end

          # assert that this includes our unarchived episode
          deliver_and_publish = ->(eps) do
            assert_equal [apple_episode.feeder_id], eps.map(&:feeder_id)
            true
          end

          # eliminate calls to the apple api
          apple_publisher.show.stub(:sync!, []) do
            apple_publisher.stub(:poll_episodes!, []) do
              # 1) episodes are unarchived
              apple_publisher.stub(:unarchive!, unarchiver) do
                # 2) then the unarchived episodes are passed in ready to have
                # media uploaded and episode published)
                apple_publisher.stub(:deliver_and_publish!, deliver_and_publish) do
                  apple_publisher.publish!
                end
              end
            end
          end
        end
      end
    end
  end

  describe "#episodes_to_sync" do
    let(:episode) { create(:episode, podcast: podcast) }

    before do
      public_feed.episodes.delete(episode)
      private_feed.episodes << episode
    end

    it "should return the episodes to sync" do
      apple_publisher.show.stub(:apple_id, "123") do
        assert_equal apple_publisher.episodes_to_sync.map(&:feeder_id), [episode.id]

        # derived from the underlying feeds
        assert_equal public_feed.feed_episodes.map(&:id), []
        assert_equal private_feed.feed_episodes.map(&:id), [episode.id]
      end
    end

    it "should be initialized with the publishers api reference" do
      apple_publisher.show.stub(:apple_id, "123") do
        assert_equal apple_publisher.episodes_to_sync.first.api.object_id, apple_api.object_id
      end
    end
  end

  describe "#publish_drafting!" do
    let(:episode1) { build(:uploaded_apple_episode, show: apple_publisher.show, api_response: build(:apple_episode_api_response, publishing_state: "DRAFTING")) }
    let(:episode2) { build(:uploaded_apple_episode, show: apple_publisher.show, api_response: build(:apple_episode_api_response, publishing_state: "DRAFTING")) }
    let(:episodes) { [episode1, episode2] }

    it "should call the episode publish drafting class method" do
      mock = Minitest::Mock.new
      mock.expect(:call, [], [Apple::Api, Apple::Show, episodes])

      Apple::Episode.stub(:publish, mock) do
        apple_publisher.publish_drafting!(episodes)
      end

      assert mock.verify
    end
  end

  describe "#reset_asset_wait!" do
    let(:episode1) { build(:uploaded_apple_episode, show: apple_publisher.show) }
    let(:episode2) { build(:uploaded_apple_episode, show: apple_publisher.show) }
    let(:episodes) { [episode1, episode2] }

    it "should reset the asset processing attempts" do
      episodes.each do |ep|
        ep.feeder_episode.apple_update_delivery_status(asset_processing_attempts: 3)
      end
      assert_equal 3, episode1.delivery_status.asset_processing_attempts
      assert_equal 3, episode2.delivery_status.asset_processing_attempts

      apple_publisher.reset_asset_wait!(episodes)

      assert_equal 0, episode1.delivery_status.asset_processing_attempts
      assert_equal 0, episode2.delivery_status.asset_processing_attempts
    end

    it "should reset the asset processing attempts for non-drafting episodes" do
      episodes.each do |ep|
        ep.feeder_episode.apple_update_delivery_status(asset_processing_attempts: 3)
      end

      assert_equal 3, episode1.delivery_status.asset_processing_attempts
      assert_equal 3, episode2.delivery_status.asset_processing_attempts

      apple_publisher.reset_asset_wait!(episodes)

      assert_equal 0, episode1.delivery_status.asset_processing_attempts
      assert_equal 0, episode2.delivery_status.asset_processing_attempts
    end
  end

  describe "#wait_for_upload_processing" do
    it "should poll the podcast container state" do
      mock = Minitest::Mock.new
      mock.expect(:call, [], [apple_publisher.api, []])

      Apple::PodcastContainer.stub(:poll_podcast_container_state, mock) do
        apple_publisher.wait_for_upload_processing([])
      end

      assert mock.verify
    end
  end

  describe "#increment_asset_wait!" do
    let(:episode1) { build(:uploaded_apple_episode, show: apple_publisher.show) }
    let(:episode2) { build(:uploaded_apple_episode, show: apple_publisher.show) }
    let(:episodes) { [episode1, episode2] }

    it "should increment asset wait count for each episode" do
      episodes.each do |ep|
        assert_equal 0, ep.apple_episode_delivery_status.asset_processing_attempts
        ep.feeder_episode.apple_mark_as_uploaded!
      end

      apple_publisher.increment_asset_wait!(episodes)

      episodes.each do |ep|
        assert_equal 1, ep.apple_episode_delivery_status.asset_processing_attempts
      end
    end

    it "only increments the episodes that are still waiting" do
      assert 1, episode1.podcast_delivery_files.length
      assert 1, episode2.podcast_delivery_files.length

      episode1.feeder_episode.apple_mark_as_uploaded!
      apple_publisher.increment_asset_wait!(episodes)

      assert_equal [1, 0], [episode1, episode2].map { |ep| ep.apple_episode_delivery_status.asset_processing_attempts }
    end

    it "logs a timeout message with correct information" do
      travel_to Time.now do
        # Set up the delivery statuses
        eps = [episode1, episode2]
        eps.map { |e| e.feeder_episode.apple_episode_delivery_statuses.map(&:destroy) }

        # Here is the log of attempts
        create(:apple_episode_delivery_status, episode: episode1.feeder_episode, asset_processing_attempts: 0, created_at: 4.hour.ago)
        create(:apple_episode_delivery_status, episode: episode1.feeder_episode, asset_processing_attempts: 1, created_at: 3.hour.ago)
        create(:apple_episode_delivery_status, episode: episode1.feeder_episode, asset_processing_attempts: 2, created_at: 2.hour.ago)
        create(:apple_episode_delivery_status, episode: episode1.feeder_episode, asset_processing_attempts: 3, created_at: 1.hour.ago)
        eps.map(&:feeder_episode).map(&:reload)

        # now simulate the asset timeout
        assert publisher
        logs = capture_json_logs do
          Apple::Episode.stub :wait_for_asset_state, [true, eps] do
            error = assert_raises(RuntimeError) do
              publisher.wait_for_asset_state(eps)
            end
            expected_err = "Timeout waiting for asset state change: Episodes: [#{episode1.feeder_id}, #{episode2.feeder_id}], Attempts: 3, Asset Wait Duration: #{4 * 60 * 60}.0"
            assert_equal expected_err, error.message
          end
        end

        # look at the logs
        log = logs[0]
        assert_equal "Timed out waiting for asset state", log[:msg]
        assert_equal 30, log[:level]
        assert_equal 3, log[:attempts]
        assert_equal 4 * 60 * 60, log[:asset_wait_duration]
        assert_equal 2, log[:episode_count]
      end
    end

    it "should raise an error when wait times out" do
      episode1.apple_episode_delivery_status.update!(asset_processing_attempts: 3)

      Apple::Episode.stub(:wait_for_asset_state, [true, episodes]) do
        assert_raises(RuntimeError, "Timed out waiting for asset state. 3 attempts so far") do
          apple_publisher.wait_for_asset_state(episodes)
        end
      end
    end
  end

  describe "#raise_delivery_processing_errors" do
    let(:apple_episode) { build(:apple_episode, show: apple_publisher.show) }
    let(:asset_processing_state) { "COMPLETED" }
    let(:asset_delivery_state) { "COMPLETE" }

    let(:pdf_resp_container) { build(:podcast_delivery_file_api_response, asset_delivery_state: asset_delivery_state, asset_processing_state: asset_processing_state) }
    let(:apple_id) { {external_id: "123"} }

    let(:podcast_container) { create(:apple_podcast_container, episode: apple_episode.feeder_episode) }
    let(:podcast_delivery) { Apple::PodcastDelivery.create!(podcast_container: podcast_container, episode: apple_episode.feeder_episode) }
    let(:podcast_delivery_file) { Apple::PodcastDeliveryFile.new(apple_sync_log: SyncLog.new(**pdf_resp_container.merge(apple_id)), podcast_delivery: podcast_delivery, episode: apple_episode.feeder_episode) }

    before do
      assert podcast_container.save!
      assert podcast_delivery.save!
      assert podcast_delivery_file.save!
    end

    it "should not raise an error if there are no processing errors" do
      refute podcast_delivery_file.processed_errors?
      assert_equal apple_publisher.raise_delivery_processing_errors([apple_episode]), true
    end

    describe "non completed/complete states" do
      let(:asset_processing_state) { "VALIDATION_FAILED" }
      it "should raise an error if there are processing errors" do
        assert podcast_delivery_file.processed_errors?
        assert_raises(Apple::PodcastDeliveryFile::DeliveryFileError) do
          apple_publisher.raise_delivery_processing_errors([apple_episode])
        end
      end
    end

    describe "#prepare_for_delivery" do
      it "should call into the apple episode class method" do
        mock = Minitest::Mock.new
        mock.expect(:call, [], [[]])

        Apple::Episode.stub(:prepare_for_delivery, mock) do
          apple_publisher.prepare_for_delivery!([])
        end

        mock.verify
      end
    end
  end

  describe "#mark_as_uploaded!" do
    let(:episode1) { build(:uploaded_apple_episode, show: apple_publisher.show) }
    let(:episode2) { build(:uploaded_apple_episode, show: apple_publisher.show) }
    let(:episodes) { [episode1, episode2] }

    it "marks episodes as uploaded" do
      episodes.each do |ep|
        refute ep.delivery_status.uploaded
      end

      apple_publisher.mark_as_uploaded!(episodes)

      episodes.each do |ep|
        assert ep.delivery_status.uploaded
      end
    end
  end

  describe "#mark_as_delivered!" do
    let(:episode1) { build(:apple_episode, show: apple_publisher.show) }
    let(:episode2) { build(:apple_episode, show: apple_publisher.show) }
    let(:episodes) { [episode1, episode2] }

    it "marks episodes as delivered" do
      episodes.each do |ep|
        refute ep.delivery_status.delivered
      end

      apple_publisher.mark_as_delivered!(episodes)

      episodes.each do |ep|
        assert ep.delivery_status.delivered
      end
    end
  end

  describe "#update_audio_container_reference!" do
    let(:episode) { build(:uploaded_apple_episode, show: apple_publisher.show, apple_hosted_audio_asset_container_id: nil) }

    it "updates container references for episodes" do
      assert episode.has_unlinked_container?

      mock_result = episode.apple_sync_log.api_response.deep_dup
      mock_result["api_response"]["val"]["data"]["attributes"]["appleHostedAudioAssetContainerId"] = "456"

      apple_publisher.api.stub(:bridge_remote_and_retry, [[mock_result], []]) do
        apple_publisher.update_audio_container_reference!([episode])
      end

      refute episode.has_unlinked_container?
    end
  end

  describe "#deliver_and_publish!" do
    let(:episode) { build(:uploaded_apple_episode, show: apple_publisher.show) }

    it "skips upload for already uploaded episodes" do
      episode.feeder_episode.apple_mark_as_uploaded!

      mock = Minitest::Mock.new
      episode.feeder_episode.stub(:apple_prepare_for_delivery!, ->(*) { raise "Should not be called" }) do
        mock.expect(:call, nil, [[]])
        apple_publisher.stub(:upload_media!, mock) do
          apple_publisher.stub(:process_and_deliver!, ->(*) {}) do
            apple_publisher.deliver_and_publish!([episode])
          end
        end
      end

      assert mock.verify
    end

    it "processes uploads for non-uploaded episodes" do
      refute episode.delivery_status.uploaded

      mock = Minitest::Mock.new
      mock.expect(:call, nil, [[episode]])
      apple_publisher.stub(:upload_media!, mock) do
        apple_publisher.stub(:process_and_deliver!, ->(*) {}) do
          apple_publisher.deliver_and_publish!([episode])
        end
      end

      mock.verify
    end
  end
end
