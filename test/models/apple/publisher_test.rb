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

  describe "#filter_episodes_to_archive" do
    let(:episode) { build(:apple_episode) }

    it "should filter episodes that are not in the private feed" do
      apple_publisher.stub(:episodes_to_sync, []) do
        assert_equal [episode], apple_publisher.filter_episodes_to_archive([episode])
      end

      apple_publisher.stub(:episodes_to_sync, [episode]) do
        assert_equal [], apple_publisher.filter_episodes_to_archive([episode])
      end
    end

    it "should filter episodes that don't have apple state" do
      episode.stub(:apple_new?, true) do
        apple_publisher.stub(:episodes_to_sync, []) do
          assert_equal [], apple_publisher.filter_episodes_to_archive([episode])
        end
      end
    end

    it "should filter episodes that are archived" do
      episode.stub(:archived?, true) do
        apple_publisher.stub(:episodes_to_sync, []) do
          assert_equal [], apple_publisher.filter_episodes_to_archive([episode])
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
