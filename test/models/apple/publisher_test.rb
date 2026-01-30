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
          upload_and_process = ->(eps) do
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
                apple_publisher.stub(:upload_and_process!, upload_and_process) do
                  apple_publisher.publish!
                end
              end
            end
          end
        end
      end
    end

    describe "#archive! chunking behavior" do
      it "should pass chunked episodes to Apple::Episode.archive, not all episodes" do
        # Create simple doubles instead of full episodes
        episodes = (1..30).map { |i| OpenStruct.new(feeder_id: i) }

        # Track which episode IDs are passed to Apple::Episode.archive
        archive_calls = []
        archive_mock = ->(api, show, eps) do
          archive_calls << eps.map(&:feeder_id)
          []  # return empty array
        end

        Apple::Episode.stub(:archive, archive_mock) do
          apple_publisher.archive!(episodes)
        end

        # Should have been called twice: first chunk of 25, second chunk of 5
        assert_equal 2, archive_calls.length
        assert_equal 25, archive_calls[0].length
        assert_equal 5, archive_calls[1].length

        # Verify episodes were properly chunked (no duplicates across calls)
        all_processed_ids = archive_calls.flatten
        expected_ids = (1..30).to_a
        assert_equal expected_ids.sort, all_processed_ids.sort
      end
    end

    describe "#unarchive! chunking behavior" do
      it "should pass chunked episodes to Apple::Episode.unarchive, not all episodes" do
        # Create simple doubles instead of full episodes
        episodes = (1..30).map { |i| OpenStruct.new(feeder_id: i) }

        # Track which episode IDs are passed to Apple::Episode.unarchive
        unarchive_calls = []
        unarchive_mock = ->(api, show, eps) do
          unarchive_calls << eps.map(&:feeder_id)
          []  # return empty array
        end

        Apple::Episode.stub(:unarchive, unarchive_mock) do
          apple_publisher.unarchive!(episodes)
        end

        # Should have been called twice: first chunk of 25, second chunk of 5
        assert_equal 2, unarchive_calls.length
        assert_equal 25, unarchive_calls[0].length
        assert_equal 5, unarchive_calls[1].length

        # Verify episodes were properly chunked (no duplicates across calls)
        all_processed_ids = unarchive_calls.flatten
        expected_ids = (1..30).to_a
        assert_equal expected_ids.sort, all_processed_ids.sort
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

  describe "#verify_publishing_state!" do
    let(:episode1) { build(:uploaded_apple_episode, show: apple_publisher.show, api_response: build(:apple_episode_api_response, publishing_state: "DRAFTING")) }
    let(:episode2) { build(:uploaded_apple_episode, show: apple_publisher.show, api_response: build(:apple_episode_api_response, publishing_state: "DRAFTING")) }
    let(:episodes) { [episode1, episode2] }

    it "should not raise error when episodes remain in same state" do
      apple_publisher.stub(:poll_episodes!, nil) do
        result = apple_publisher.verify_publishing_state!(episodes)
        assert result == true
      end
    end

    it "should raise RetryPublishingError when state drift is detected" do
      # Simulate state change during poll - episode1 starts DRAFTING but becomes PUBLISHED after poll
      apple_publisher.stub(:poll_episodes!, proc {
        episode1.api_response["api_response"]["val"]["data"]["attributes"]["publishingState"] = "PUBLISHED"
      }) do
        error = assert_raises(Apple::RetryPublishingError) do
          apple_publisher.verify_publishing_state!(episodes)
        end
        assert_match(/Detected 1 episodes with publishing state drift/, error.message)
      end
    end

    it "should detect drift and raise error even with non-DRAFTING episodes" do
      # episode1 starts in PUBLISHED state, then drifts to ARCHIVED
      episode1.api_response["api_response"]["val"]["data"]["attributes"]["publishingState"] = "PUBLISHED"

      apple_publisher.stub(:poll_episodes!, proc {
        episode1.api_response["api_response"]["val"]["data"]["attributes"]["publishingState"] = "ARCHIVED"
      }) do
        error = assert_raises(Apple::RetryPublishingError) do
          apple_publisher.verify_publishing_state!(episodes)
        end
        assert_match(/Detected 1 episodes with publishing state drift/, error.message)
      end
    end

    it "should raise error with count when multiple episodes drift" do
      apple_publisher.stub(:poll_episodes!, proc {
        episode1.api_response["api_response"]["val"]["data"]["attributes"]["publishingState"] = "PUBLISHED"
        episode2.api_response["api_response"]["val"]["data"]["attributes"]["publishingState"] = "ARCHIVED"
      }) do
        error = assert_raises(Apple::RetryPublishingError) do
          apple_publisher.verify_publishing_state!(episodes)
        end
        assert_match(/Detected 2 episodes with publishing state drift/, error.message)
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

      apple_publisher.stub(:verify_publishing_state!, nil) do
        Apple::Episode.stub(:publish, mock) do
          apple_publisher.publish_drafting!(episodes)
        end
      end

      assert mock.verify
    end
  end

  describe "#mark_as_delivered!" do
    let(:episode1) { build(:uploaded_apple_episode, show: apple_publisher.show) }
    let(:episode2) { build(:uploaded_apple_episode, show: apple_publisher.show) }
    let(:episodes) { [episode1, episode2] }

    it "should reset the asset processing attempts when marking as delivered" do
      episodes.each do |ep|
        ep.feeder_episode.apple_update_delivery_status(asset_processing_attempts: 3)
      end
      assert_equal 3, episode1.delivery_status.asset_processing_attempts
      assert_equal 3, episode2.delivery_status.asset_processing_attempts

      apple_publisher.mark_as_delivered!(episodes)

      assert_equal 0, episode1.delivery_status.asset_processing_attempts
      assert_equal 0, episode2.delivery_status.asset_processing_attempts
    end

    it "should mark episodes as delivered and reset asset processing attempts" do
      episodes.each do |ep|
        ep.feeder_episode.apple_update_delivery_status(asset_processing_attempts: 3, delivered: false)
      end

      assert_equal 3, episode1.delivery_status.asset_processing_attempts
      assert_equal 3, episode2.delivery_status.asset_processing_attempts
      refute episode1.delivery_status.delivered
      refute episode2.delivery_status.delivered

      apple_publisher.mark_as_delivered!(episodes)

      assert_equal 0, episode1.delivery_status.asset_processing_attempts
      assert_equal 0, episode2.delivery_status.asset_processing_attempts
      assert episode1.delivery_status.delivered
      assert episode2.delivery_status.delivered
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
        eps.each { |e| e.feeder_episode.apple_episode_delivery_statuses.map(&:destroy) }

        # Here is the log of attempts
        create(:apple_episode_delivery_status, episode: episode1.feeder_episode, asset_processing_attempts: 0, created_at: 4.hour.ago)
        create(:apple_episode_delivery_status, episode: episode1.feeder_episode, asset_processing_attempts: 1, created_at: 3.hour.ago)
        create(:apple_episode_delivery_status, episode: episode1.feeder_episode, asset_processing_attempts: 2, created_at: 2.hour.ago)
        create(:apple_episode_delivery_status, episode: episode1.feeder_episode, asset_processing_attempts: 3, created_at: 1.hour.ago)
        eps.map(&:feeder_episode).each(&:reload)

        # Mark episodes as having uploaded files
        eps.each do |ep|
          ep.podcast_delivery_files.each { |pdf| pdf.apple_sync_log.update!(**build(:podcast_delivery_file_api_response, asset_delivery_state: "COMPLETE")) }
        end

        # now simulate the asset timeout
        logs = capture_json_logs do
          # Stub wait_for to call the block once then return timeout
          wait_for_stub = ->(_remaining, wait_timeout:, wait_interval:, &block) {
            # Call the block once to simulate one iteration before timing out
            block.call(eps)
            [true, eps]  # Return timeout with remaining episodes
          }

          Apple::Publisher.stub :wait_for, wait_for_stub do
            # Need to stub probe_asset_state since it will be called
            Apple::Episode.stub :probe_asset_state, [[], eps] do
              # Stub check_for_stuck_episodes to prevent stuck detection from interfering
              publisher.stub :check_for_stuck_episodes, nil do
                error = assert_raises(RuntimeError) do
                  publisher.wait_for_asset_state(eps)
                end
                expected_err = "Timeout waiting for asset state change: Episodes: [#{episode1.feeder_id}, #{episode2.feeder_id}], Attempts: 3, Asset Wait Duration: #{4 * 60 * 60}.0"
                assert_equal expected_err, error.message
              end
            end
          end
        end

        # look at the logs
        log = logs.find { |l| l[:msg] == "Timed out waiting for asset state" }
        assert log, "Should have timeout log message"
        assert_equal 30, log[:level]
        assert_equal 3, log[:attempts]
        assert_equal 4 * 60 * 60, log[:asset_wait_duration]
        assert_equal 2, log[:episode_count]
      end
    end

    it "should raise an error when wait times out" do
      episode1.apple_episode_delivery_status.update!(asset_processing_attempts: 3)

      wait_for_stub = ->(_remaining, wait_timeout:, wait_interval:, &block) {
        [true, episodes]  # Just return timeout tuple, don't call block
      }

      Apple::Publisher.stub(:wait_for, wait_for_stub) do
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
    let(:apple_id) { {external_id: "123", integration: :apple} }

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

    describe "VALIDATION_FAILED processing state" do
      let(:asset_processing_state) { "VALIDATION_FAILED" }
      it "should raise an error" do
        assert podcast_delivery_file.processed_errors?
        assert_raises(Apple::PodcastDeliveryFile::DeliveryFileError) do
          apple_publisher.raise_delivery_processing_errors([apple_episode])
        end
      end
    end

    describe "DUPLICATE processing state" do
      let(:asset_processing_state) { "DUPLICATE" }
      it "should not raise an error and proceed with delivery" do
        assert podcast_delivery_file.processed_duplicate?
        refute podcast_delivery_file.processed_errors?
        assert_equal true, apple_publisher.raise_delivery_processing_errors([apple_episode])
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

  describe "#upload_and_process!" do
    let(:episode) { build(:uploaded_apple_episode, show: apple_publisher.show) }

    it "skips upload for already uploaded episodes" do
      episode.feeder_episode.apple_mark_as_uploaded!

      # Track if upload_media! was called
      upload_called = false
      upload_mock = ->(eps) do
        upload_called = true
      end

      apple_publisher.stub(:upload_media!, upload_mock) do
        apple_publisher.stub(:process_delivery!, ->(*) {}) do
          apple_publisher.stub(:verify_publishing_state!, nil) do
            apple_publisher.upload_and_process!([episode])
          end
        end
      end

      refute upload_called, "upload_media! should not be called for already uploaded episodes"
    end

    it "processes uploads for non-uploaded episodes" do
      refute episode.delivery_status.uploaded

      mock = Minitest::Mock.new
      mock.expect(:call, nil, [[episode]])
      apple_publisher.stub(:upload_media!, mock) do
        apple_publisher.stub(:process_delivery!, ->(*) {}) do
          apple_publisher.stub(:verify_publishing_state!, nil) do
            apple_publisher.upload_and_process!([episode])
          end
        end
      end

      mock.verify
    end

    it "calls delivery for episodes needing delivery" do
      episode.feeder_episode.apple_mark_as_uploaded!
      episode.feeder_episode.apple_mark_as_not_delivered!

      # Delivery should be called (which now includes publishing)
      delivery_mock = Minitest::Mock.new
      delivery_mock.expect(:call, nil, [[episode]])

      apple_publisher.stub(:upload_media!, ->(*) {}) do
        apple_publisher.stub(:process_delivery!, delivery_mock) do
          apple_publisher.upload_and_process!([episode])
        end
      end

      assert delivery_mock.verify
    end

    it "processes all uploads before any deliveries (phase separation)" do
      # Create episodes in different states
      upload_episode = build(:uploaded_apple_episode, show: apple_publisher.show)
      delivery_episode = build(:uploaded_apple_episode, show: apple_publisher.show)

      # Force upload episode to need upload
      upload_episode.feeder_episode.apple_mark_as_not_uploaded!
      upload_episode.feeder_episode.apple_mark_as_not_delivered!
      assert upload_episode.apple_needs_upload?

      # Force delivery episode to need delivery but not upload
      delivery_episode.feeder_episode.apple_mark_as_not_delivered!
      delivery_episode.feeder_episode.apple_mark_as_uploaded!

      refute delivery_episode.feeder_episode.apple_needs_upload?
      assert delivery_episode.apple_needs_delivery?

      episodes = [upload_episode, delivery_episode]

      # Track call order to verify uploads happen before deliveries
      call_order = []

      upload_mock = ->(eps) do
        call_order << :upload_phase
        # Should only get episodes that need upload
        assert Set.new(eps) == Set.new([upload_episode])
      end

      delivery_mock = ->(eps) do
        call_order << :delivery_phase
        # Should only get episodes that need delivery
        assert Set.new(eps) == Set.new([delivery_episode, upload_episode])
      end

      publish_mock = ->(eps) do
        # publish_drafting! is called for each delivery chunk
      end

      apple_publisher.stub(:upload_media!, upload_mock) do
        apple_publisher.stub(:process_delivery!, delivery_mock) do
          apple_publisher.stub(:publish_drafting!, publish_mock) do
            apple_publisher.upload_and_process!(episodes)
          end
        end
      end

      # Verify uploads happened before deliveries
      assert_equal [:upload_phase, :delivery_phase], call_order
    end

    it "calls increment_asset_wait! immediately after upload completion" do
      episode = build(:uploaded_apple_episode, show: apple_publisher.show)

      # Track method calls to verify increment_asset_wait! is called during upload_media!
      upload_method_calls = []
      increment_called_during_upload = false

      upload_mock = ->(eps) do
        upload_method_calls << :upload_started
        # Simulate the actual upload_media! behavior where increment_asset_wait! is called
        apple_publisher.increment_asset_wait!(eps)
        increment_called_during_upload = true
        upload_method_calls << :upload_completed
      end

      # Mock increment_asset_wait! to track when it's called
      increment_mock = Minitest::Mock.new
      increment_mock.expect(:call, nil, [[episode]])

      apple_publisher.stub(:upload_media!, upload_mock) do
        apple_publisher.stub(:increment_asset_wait!, increment_mock) do
          apple_publisher.stub(:process_delivery!, ->(*) {}) do
            apple_publisher.stub(:publish_drafting!, ->(*) {}) do
              apple_publisher.upload_and_process!([episode])
            end
          end
        end
      end

      # Verify increment_asset_wait! was called during upload phase
      assert increment_called_during_upload, "increment_asset_wait! should be called during upload_media!"
      assert increment_mock.verify
    end
  end

  describe "#process_delivery!" do
    let(:episode) { build(:uploaded_apple_episode, show: apple_publisher.show) }

    it "processes ready episodes immediately within wait_for loop" do
      # Mark episode as having uploaded files
      episode.podcast_delivery_files.each { |pdf| pdf.apple_sync_log.update!(**build(:podcast_delivery_file_api_response, asset_delivery_state: "COMPLETE")) }

      # Setup mocks to verify method calls
      increment_mock = Minitest::Mock.new
      increment_mock.expect(:call, nil, [[episode]])

      wait_upload_mock = Minitest::Mock.new
      wait_upload_mock.expect(:call, nil, [[episode]])

      # Mock probe_asset_state to return episode as ready immediately
      probe_mock = ->(api, eps) {
        # Return all as ready, none waiting
        [eps, []]
      }

      mark_delivered_called = false
      mark_delivered_mock = ->(eps) {
        mark_delivered_called = true
        assert_equal [episode], eps
      }

      # Stub wait_for_asset_state to use fast timeouts
      original_wait_for_asset_state = apple_publisher.method(:wait_for_asset_state)
      wait_for_asset_state_stub = ->(eps, **_kwargs, &block) {
        original_wait_for_asset_state.call(eps, wait_timeout: 0.seconds, wait_interval: 0.seconds, &block)
      }

      # Set up method stubs
      apple_publisher.stub(:increment_asset_wait!, increment_mock) do
        apple_publisher.stub(:wait_for_upload_processing, wait_upload_mock) do
          apple_publisher.stub(:wait_for_asset_state, wait_for_asset_state_stub) do
            apple_publisher.stub(:verify_publishing_state!, ->(*) {}) do
              Apple::Episode.stub(:probe_asset_state, probe_mock) do
                apple_publisher.stub(:mark_as_delivered!, mark_delivered_mock) do
                  apple_publisher.process_delivery!([episode])
                end
              end
            end
          end
        end
      end

      # Verify all expected methods were called
      assert increment_mock.verify
      assert wait_upload_mock.verify
      assert mark_delivered_called
    end

    it "publishes episodes before marking them as delivered" do
      # Mark episode as having uploaded files
      episode.podcast_delivery_files.each { |pdf| pdf.apple_sync_log.update!(**build(:podcast_delivery_file_api_response, asset_delivery_state: "COMPLETE")) }

      # Track only the critical ordering: publish must happen before mark_as_delivered
      call_order = []

      # Stub wait_for_asset_state to use fast timeouts and return episode as ready
      original_wait_for_asset_state = apple_publisher.method(:wait_for_asset_state)
      wait_for_asset_state_stub = ->(eps, **_kwargs, &block) {
        original_wait_for_asset_state.call(eps, wait_timeout: 0.seconds, wait_interval: 0.seconds, &block)
      }

      apple_publisher.stub(:increment_asset_wait!, ->(*) {}) do
        apple_publisher.stub(:wait_for_upload_processing, ->(*) {}) do
          apple_publisher.stub(:wait_for_asset_state, wait_for_asset_state_stub) do
            Apple::Episode.stub(:probe_asset_state, ->(api, eps) { [eps, []] }) do
              apple_publisher.stub(:log_asset_wait_duration!, ->(*) {}) do
                apple_publisher.stub(:publish_drafting!, ->(eps) {
                  call_order << :publish
                  assert_equal [episode], eps
                }) do
                  apple_publisher.stub(:mark_as_delivered!, ->(eps) {
                    call_order << :mark_delivered
                    assert_equal [episode], eps
                  }) do
                    apple_publisher.process_delivery!([episode])
                  end
                end
              end
            end
          end
        end
      end

      # Verify the critical business rule: publish happens before mark_as_delivered
      assert_equal [:publish, :mark_delivered], call_order, "Episodes must be published before being marked as delivered"
    end

    it "continues waiting for episodes not ready yet" do
      # Mark episode as having uploaded files but not ready
      episode.podcast_delivery_files.each { |pdf| pdf.apple_sync_log.update!(**build(:podcast_delivery_file_api_response, asset_delivery_state: "COMPLETE")) }

      # Mock probe_asset_state to return episode as waiting on first call, ready on second
      probe_call_count = 0
      probe_mock = ->(api, eps) {
        probe_call_count += 1
        if probe_call_count == 1
          # First call: still waiting
          [[], eps]
        else
          # Otherwise: ready
          [eps, []]
        end
      }

      # Stub wait_for_asset_state to use fast timeouts
      original_wait_for_asset_state = apple_publisher.method(:wait_for_asset_state)
      wait_for_asset_state_stub = ->(eps, **_kwargs, &block) {
        original_wait_for_asset_state.call(eps, wait_timeout: 100.0.seconds, wait_interval: 0.0.seconds, &block)
      }

      apple_publisher.stub(:increment_asset_wait!, ->(*) {}) do
        apple_publisher.stub(:wait_for_upload_processing, ->(*) {}) do
          apple_publisher.stub(:wait_for_asset_state, wait_for_asset_state_stub) do
            apple_publisher.stub(:check_for_stuck_episodes, ->(*) {}) do
              apple_publisher.stub(:verify_publishing_state!, ->(*) {}) do
                Apple::Episode.stub(:probe_asset_state, probe_mock) do
                  apple_publisher.stub(:mark_as_delivered!, ->(*) {}) do
                    apple_publisher.stub(:log_asset_wait_duration!, ->(*) {}) do
                      apple_publisher.process_delivery!([episode])
                    end
                  end
                end
              end
            end
          end
        end
      end

      assert probe_call_count == 2
    end

    it "processes episodes in batches of PUBLISH_CHUNK_LEN" do
      # Create 75 test doubles (3 batches of 25)
      # Use simple doubles instead of expensive full episode instances
      episodes = (1..75).map { |i|
        pdf = OpenStruct.new(api_marked_as_uploaded?: true)
        OpenStruct.new(
          feeder_id: i,
          podcast_delivery_files: [pdf]
        )
      }

      batch_sizes = []
      probe_mock = ->(api, eps) {
        batch_sizes << eps.length
        # Return all as ready
        [eps, []]
      }

      # Stub wait_for_asset_state to use fast timeouts
      original_wait_for_asset_state = apple_publisher.method(:wait_for_asset_state)
      wait_for_asset_state_stub = ->(eps, **_kwargs, &block) {
        original_wait_for_asset_state.call(eps, wait_timeout: 0.seconds, wait_interval: 0.seconds, &block)
      }

      apple_publisher.stub(:increment_asset_wait!, ->(*) {}) do
        apple_publisher.stub(:wait_for_upload_processing, ->(*) {}) do
          apple_publisher.stub(:wait_for_asset_state, wait_for_asset_state_stub) do
            apple_publisher.stub(:verify_publishing_state!, ->(*) {}) do
              Apple::Episode.stub(:probe_asset_state, probe_mock) do
                apple_publisher.stub(:mark_as_delivered!, ->(*) {}) do
                  apple_publisher.stub(:log_asset_wait_duration!, ->(*) {}) do
                    apple_publisher.process_delivery!(episodes)
                  end
                end
              end
            end
          end
        end
      end

      # Should have been called with three batches of 25 each
      assert_equal [25, 25, 25], batch_sizes
    end

    it "processes mixed ready/waiting episodes across multiple iterations" do
      episode1 = build(:uploaded_apple_episode, show: apple_publisher.show)
      episode2 = build(:uploaded_apple_episode, show: apple_publisher.show)
      episode3 = build(:uploaded_apple_episode, show: apple_publisher.show)

      # Mark all episodes as having uploaded files
      [episode1, episode2, episode3].each do |ep|
        ep.podcast_delivery_files.each { |pdf| pdf.apple_sync_log.update!(**build(:podcast_delivery_file_api_response, asset_delivery_state: "COMPLETE")) }
      end

      # Track what happens in each iteration
      probe_call_count = 0
      probe_mock = ->(api, eps) {
        probe_call_count += 1
        case probe_call_count
        when 1
          # First iteration: episode1 ready, others waiting
          [[episode1], [episode2, episode3]]
        when 2
          # Second iteration: episode2 ready, episode3 still waiting
          [[episode2], [episode3]]
        else
          # Third iteration: episode3 finally ready
          [[episode3], []]
        end
      }

      # Track which episodes were marked as delivered
      delivered_episodes = []
      mark_delivered_mock = ->(eps) {
        delivered_episodes.concat(eps)
      }

      # Stub wait_for_asset_state to use fast timeouts
      original_wait_for_asset_state = apple_publisher.method(:wait_for_asset_state)
      wait_for_asset_state_stub = ->(eps, **_kwargs, &block) {
        original_wait_for_asset_state.call(eps, wait_timeout: 100.seconds, wait_interval: 0.seconds, &block)
      }

      apple_publisher.stub(:increment_asset_wait!, ->(*) {}) do
        apple_publisher.stub(:wait_for_upload_processing, ->(*) {}) do
          apple_publisher.stub(:wait_for_asset_state, wait_for_asset_state_stub) do
            apple_publisher.stub(:check_for_stuck_episodes, ->(*) {}) do
              apple_publisher.stub(:verify_publishing_state!, ->(*) {}) do
                Apple::Episode.stub(:probe_asset_state, probe_mock) do
                  apple_publisher.stub(:mark_as_delivered!, mark_delivered_mock) do
                    apple_publisher.process_delivery!([episode1, episode2, episode3])
                  end
                end
              end
            end
          end
        end
      end

      # Verify all three episodes were eventually processed
      assert_equal 3, probe_call_count
      assert_equal [episode1, episode2, episode3].map(&:feeder_id).sort, delivered_episodes.map(&:feeder_id).sort
    end

    it "times out when wait_for exceeds timeout without stuck episodes" do
      episode1 = build(:uploaded_apple_episode, show: apple_publisher.show)
      episode2 = build(:uploaded_apple_episode, show: apple_publisher.show)

      # Mark episodes as having uploaded files
      [episode1, episode2].each do |ep|
        ep.podcast_delivery_files.each { |pdf| pdf.apple_sync_log.update!(**build(:podcast_delivery_file_api_response, asset_delivery_state: "COMPLETE")) }
      end

      # Track probe calls to verify timeout behavior
      probe_call_count = 0
      probe_mock = ->(api, eps) {
        probe_call_count += 1
        # Always return episodes as waiting (never ready)
        [[], eps]
      }

      # Track which episodes were marked as delivered (should be none)
      delivered_episodes = []
      mark_delivered_mock = ->(eps) {
        delivered_episodes.concat(eps)
      }

      # Mock to return short durations (not stuck)
      episode1.feeder_episode.stub(:measure_asset_processing_duration, 300) do
        episode2.feeder_episode.stub(:measure_asset_processing_duration, 600) do
          # Stub wait_for_asset_state to force timeout
          original_wait_for_asset_state = apple_publisher.method(:wait_for_asset_state)
          wait_for_asset_state_stub = ->(eps, **_kwargs, &block) {
            original_wait_for_asset_state.call(eps, wait_timeout: 0.seconds, wait_interval: 0.seconds, &block)
          }

          apple_publisher.stub(:increment_asset_wait!, ->(*) {}) do
            apple_publisher.stub(:wait_for_upload_processing, ->(*) {}) do
              apple_publisher.stub(:wait_for_asset_state, wait_for_asset_state_stub) do
                apple_publisher.stub(:check_for_stuck_episodes, ->(*) {}) do
                  apple_publisher.stub(:verify_publishing_state!, ->(*) {}) do
                    Apple::Episode.stub(:probe_asset_state, probe_mock) do
                      apple_publisher.stub(:mark_as_delivered!, mark_delivered_mock) do
                        apple_publisher.stub(:log_asset_wait_duration!, ->(*) {}) do
                          # Should raise timeout error when timeout is reached
                          error = assert_raises(Apple::AssetStateTimeoutError) do
                            apple_publisher.process_delivery!([episode1, episode2])
                          end

                          assert_equal 2, error.episodes.length, "Error should contain both episodes"
                        end
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end

      # Verify probe was called at least once (timeout didn't prevent it from running)
      assert probe_call_count >= 1, "probe_asset_state should be called at least once"
      # Verify no episodes were marked as delivered (they never became ready)
      assert_empty delivered_episodes, "No episodes should be marked as delivered when timeout occurs"
    end
  end

  describe "#check_for_stuck_episodes" do
    let(:episode1) { build(:uploaded_apple_episode, show: apple_publisher.show) }
    let(:episode2) { build(:uploaded_apple_episode, show: apple_publisher.show) }

    it "raises AssetStateTimeoutError for episodes stuck over 1 hour and marks them for reupload" do
      # Track which episodes were marked for reupload
      reupload_calls = []

      # Capture episode references for closure
      ep1 = episode1
      ep2 = episode2

      episode1.define_singleton_method(:apple_mark_for_reupload!) do
        reupload_calls << ep1.feeder_id
      end
      episode2.define_singleton_method(:apple_mark_for_reupload!) do
        reupload_calls << ep2.feeder_id
      end

      # Mock episodes to return durations over 1 hour
      episode1.feeder_episode.stub(:measure_asset_processing_duration, 3700) do
        episode2.feeder_episode.stub(:measure_asset_processing_duration, 4000) do
          error = assert_raises(Apple::AssetStateTimeoutError) do
            apple_publisher.send(:check_for_stuck_episodes, [episode1, episode2])
          end

          assert_equal 2, error.episodes.length
          # Verify both episodes were marked for reupload
          assert_equal [episode1.feeder_id, episode2.feeder_id].sort, reupload_calls.sort
        end
      end
    end

    it "does not raise for episodes waiting less than 1 hour" do
      episode1.feeder_episode.stub(:measure_asset_processing_duration, 1800) do
        episode2.feeder_episode.stub(:measure_asset_processing_duration, 2400) do
          # Should not raise
          result = apple_publisher.send(:check_for_stuck_episodes, [episode1, episode2])
          assert_nil result
        end
      end
    end

    it "does nothing for empty waiting list" do
      # Should not raise or log anything
      result = apple_publisher.send(:check_for_stuck_episodes, [])
      assert_nil result
    end
  end
end
