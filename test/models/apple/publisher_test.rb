# frozen_string_literal: true

require "test_helper"

describe Apple::Publisher do
  let(:podcast) { create(:podcast) }
  let(:public_feed) { create(:feed, podcast: podcast, private: false) }
  let(:private_feed) { create(:feed, podcast: podcast, private: true) }
  let(:apple_config) { build(:apple_config) }
  let(:apple_api) { Apple::Api.from_apple_config(apple_config) }

  let(:apple_publisher) do
    Apple::Publisher.new(api: apple_api, public_feed: public_feed, private_feed: private_feed)
  end

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
        assert_equal apple_publisher.only_episodes_with_apple_state([episode]), []
      end
      episode.stub(:apple_new?, false) do
        assert_equal apple_publisher.only_episodes_with_apple_state([episode]), [episode]
      end
    end
  end

  describe "#filter_episodes_to_sync" do
    let(:podcast) { create(:podcast) }

    let(:public_feed) { create(:feed, podcast: podcast, private: false) }
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

  describe "Archive and Unarchive flows" do
    let(:podcast) { create(:podcast) }
    let(:public_feed) { create(:feed, podcast: podcast, private: false) }
    let(:private_feed) { create(:private_feed, podcast: podcast) }
    let(:apple_config) { create(:apple_config, public_feed: public_feed, private_feed: private_feed) }
    let(:episode) { create(:episode, podcast: podcast) }
    let(:apple_episode_api_response) { build(:apple_episode_api_response, apple_episode_id: "123") }
    let(:apple_publisher) { apple_config.build_publisher }
    let(:apple_api) { apple_publisher.api }
    let(:apple_episode) { Apple::Episode.new(show: apple_publisher.show, feeder_episode: episode, api: apple_api) }

    before do
      Apple::Show.connect_existing("123", apple_config)
      episode.create_apple_sync_log(external_id: "123", **apple_episode_api_response)
    end

    describe "#episodes_to_archive" do
      it "should select episodes that are not in the private feed" do
        # it's in the feed
        assert_equal [episode], private_feed.feed_episodes
        # so no archive
        assert_equal [], apple_publisher.episodes_to_archive

        private_feed.update!(exclude_tags: ["apple-excluded"])
        episode.update!(categories: ["apple-excluded"])
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
      end

      it "should archive an upublished episode" do
        apple_episode.feeder_episode.update!(published_at: nil, released_at: nil)
        refute apple_episode.published?

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
    end
  end

  describe "#episodes_to_sync" do
    let(:episode) { create(:episode, podcast: podcast) }

    before do
      episode.categories = ["bonus"]
      public_feed.exclude_tags = ["bonus"]
      public_feed.save!
      episode.save!
    end

    it "should return the episodes to sync" do
      apple_publisher.show.stub(:apple_id, "123") do
        assert_equal apple_publisher.episodes_to_sync.map(&:feeder_id), [episode.id]

        # derived from the underlying feeds
        assert_equal public_feed.filtered_episodes.map(&:id), []
        assert_equal private_feed.filtered_episodes.map(&:id), [episode.id]
      end
    end

    it "should be initialized with the publishers api reference" do
      apple_publisher.show.stub(:apple_id, "123") do
        assert_equal apple_publisher.episodes_to_sync.first.api.object_id, apple_api.object_id
      end
    end
  end

  describe "#publish_drafting!" do
    it "should call the episode publish drafting class method" do
      ep = OpenStruct.new(drafting?: true, container_upload_complete?: true)
      mock = Minitest::Mock.new
      mock.expect(:call, [], [apple_publisher.api, apple_publisher.show, [ep]])

      Apple::Episode.stub(:publish, mock) do
        apple_publisher.publish_drafting!([ep])
      end

      mock.verify
    end
  end

  describe "#wait_for_upload_processing" do
    it "should poll the podcast container state" do
      mock = Minitest::Mock.new
      mock.expect(:call, [], [apple_publisher.api, []])

      Apple::PodcastContainer.stub(:poll_podcast_container_state, mock) do
        apple_publisher.wait_for_upload_processing([])
      end

      mock.verify
    end
  end
end
