# frozen_string_literal: true

require "test_helper"

describe Apple::Show do
  let(:podcast) { create(:episode).podcast }
  let(:apple_api) { Apple::Api.from_apple_config(apple_config) }
  let(:public_feed) { podcast.default_feed }
  let(:private_feed) { create(:private_feed, podcast: podcast) }
  let(:apple_config) { build(:apple_config, feed: private_feed) }
  let(:apple_show) { Apple::Show.connect_existing("123", apple_config) }

  before do
    stub_request(:get, "https://api.podcastsconnect.apple.com/v1/countriesAndRegions?limit=200")
      .to_return(status: 200, body: json_file(:apple_countries_and_regions), headers: {})
  end

  describe ".from_apple_config" do
    it "can be created from an apple config" do
      show = apple_config.build_show
      assert show.is_a?(Apple::Show)
      assert_equal show.public_feed, public_feed
      assert_equal show.private_feed, private_feed
    end
  end

  describe "#reload" do
    it "flushes memoized attrs" do
      apple_show.instance_variable_set(:@apple_episode_json, "foo")
      apple_show.instance_variable_set(:@podcast_feeder_episodes, "foo")
      apple_show.instance_variable_set(:@podcast_episodes, "foo")
      apple_show.instance_variable_set(:@episodes, "foo")
      apple_show.instance_variable_set(:@episode_ids, "foo")
      apple_show.instance_variable_set(:@find_episode, "foo")
      apple_show.instance_variable_set(:@apple_id_to_apple_json, "foo")
      apple_show.instance_variable_set(:@guid_to_apple_json, "foo")
      apple_show.reload
      assert_nil apple_show.instance_variable_get(:@apple_episode_json)
      assert_nil apple_show.instance_variable_get(:@podcast_feeder_episodes)
      assert_nil apple_show.instance_variable_get(:@podcast_episodes)
      assert_nil apple_show.instance_variable_get(:@episodes)
      assert_nil apple_show.instance_variable_get(:@episode_ids)
      assert_nil apple_show.instance_variable_get(:@find_episode)
      assert_nil apple_show.instance_variable_get(:@apple_id_to_apple_json)
      assert_nil apple_show.instance_variable_get(:@guid_to_apple_json)
    end
  end

  describe "#podcast_feeder_episodes" do
    it "should return an array of Episode" do
      assert_equal apple_show.podcast_feeder_episodes.count, 1
      assert_equal apple_show.podcast_feeder_episodes.first.class, Episode
    end

    it "includes deleted episodes" do
      Episode.where(podcast_id: podcast.id).first.update!(deleted_at: Time.now.utc)

      assert_equal apple_show.podcast_feeder_episodes.count, 1
      assert apple_show.podcast_feeder_episodes.first.deleted?
    end

    it "de-duplicates episodes based on the item_guid" do
      assert_equal Episode.where(podcast_id: podcast.id).length, 1

      episode = Episode.where(podcast_id: podcast.id).first
      episode.update!(original_guid: "123", deleted_at: Time.now.utc)

      # add another episode with the same guid
      episode2 = create(:episode, podcast: podcast, item_guid: "123")

      assert_equal apple_show.podcast_feeder_episodes.count, 1
      assert_equal apple_show.podcast_feeder_episodes.first.id, episode2.id
    end

    describe "#sort_by_episode_properties" do
      it "sorts by multiple attributes in descending priority" do
        now = Time.now.utc

        recs = [
          OpenStruct.new(deleted_at: now, published_at: now, created_at: now, id: 1),
          OpenStruct.new(deleted_at: now, published_at: now + 1.second, created_at: now, id: 2),
          OpenStruct.new(deleted_at: now, published_at: now + 1.second, created_at: now + 1.second, id: 3),
          OpenStruct.new(deleted_at: nil, published_at: now + 1.second, created_at: now + 1.second, id: 4),
          OpenStruct.new(deleted_at: nil, published_at: now + 1.second, created_at: now + 2.second, id: 5),
          OpenStruct.new(deleted_at: nil, published_at: now + 2.second, created_at: now + 2.second, id: 6)
        ]

        assert_equal [6, 5, 4, 3, 2, 1], apple_show.sort_by_episode_properties(recs).map(&:id)
      end

      it "sorts by presence of deleted_at" do
        now = Time.now.utc

        recs = [
          OpenStruct.new(deleted_at: now, published_at: now, created_at: now, id: 1),
          OpenStruct.new(deleted_at: nil, published_at: now, created_at: now, id: 2)
        ]

        assert_equal [2, 1], apple_show.sort_by_episode_properties(recs).map(&:id)
      end

      it "sorts by presence of published_at" do
        now = Time.now.utc

        recs = [
          OpenStruct.new(deleted_at: now, published_at: nil, created_at: now, id: 1),
          OpenStruct.new(deleted_at: now, published_at: now, created_at: now, id: 2)
        ]

        # unpublished is less than published
        assert_equal [2, 1], apple_show.sort_by_episode_properties(recs).map(&:id)
      end

      it "published_at falls back to created_at" do
        now = Time.now.utc

        recs = [
          OpenStruct.new(deleted_at: now, published_at: nil, created_at: now, id: 1),
          OpenStruct.new(deleted_at: now, published_at: nil, created_at: now + 1.second, id: 2)
        ]

        # unpublished is less than published
        assert_equal [2, 1], apple_show.sort_by_episode_properties(recs).map(&:id)
      end
    end
  end

  describe "#episodes" do
    before do
      Apple::Show.connect_existing("123", apple_config)
    end

    it "returns an array of Apple::Episode" do
      assert_equal 1, apple_show.episodes.count
      assert_equal Apple::Episode, apple_show.episodes.first.class
      assert_equal apple_show, apple_show.episodes.first.show
    end

    it "returns memoized instances of Apple::Episode" do
      obj_id = apple_show.episodes.first.object_id
      # These are not the same objects
      assert_equal apple_show.episodes.first.object_id, obj_id
    end

    it "returns the same base Feeder Episode" do
      obj_id = apple_show.episodes.first.feeder_episode.object_id
      # These feeder episodes are the same
      assert_equal apple_show.episodes.first.feeder_episode.object_id, obj_id

      # now reload
      apple_show.reload
      refute_equal apple_show.episodes.first.feeder_episode.object_id, obj_id
    end

    it "filters out the deleted episodes" do
      assert_equal 1, apple_show.episodes.count
      apple_show.episodes.first.feeder_episode.update!(deleted_at: Time.now.utc)

      apple_show.reload
      assert_equal 0, apple_show.episodes.count
    end
  end

  describe ".connect_existing" do
    let(:apple_config) { create(:apple_config, feed: private_feed) }

    it "should take in the apple show id an apple credentials object" do
      apple_config.save!
      apple_show = Apple::Show.connect_existing("some_apple_id", apple_config)

      assert_equal apple_show.apple_id, "some_apple_id"
      assert_equal apple_show.public_feed, apple_config.public_feed
      assert_equal apple_show.private_feed, apple_config.private_feed

      # it can be reloaded from the db
      apple_publisher = Apple::Publisher.from_apple_config(apple_config.reload)
      assert_equal apple_publisher.show.apple_id, "some_apple_id"
    end

    it "should take in a new apple show id" do
      apple_config.save!
      apple_show = Apple::Show.connect_existing("some_apple_id", apple_config)
      assert_equal apple_show.apple_id, "some_apple_id"
      apple_show = Apple::Show.connect_existing("another_apple_id", apple_config)
      apple_show.public_feed.reload
      assert_equal apple_show.apple_id, "another_apple_id"
    end
  end

  describe "#apple_id" do
    it "should return nil if not set" do
      apple_show.sync_log.destroy
      apple_show.public_feed.reload

      assert_nil apple_show.apple_id
    end
  end

  describe "#sync!" do
    it "runs sync!" do
      # TODO, do we need update the show?
      # apple_show.api.stub(:patch, OpenStruct.new(body: {"data" => {"id" => "123", "attributes" => {"foo" => "bar"}}}.to_json, code: "200")) do
      apple_show.api.stub(:get, OpenStruct.new(body: {"data" => {"id" => "123", "attributes" => {"foo" => "bar"}}}.to_json, code: "200")) do
        assert apple_show.sync_log.present?
        apple_show.sync_log.update!(api_response: {})

        sync = apple_show.sync!

        assert_equal sync.class, SyncLog

        assert_equal "123", sync.external_id
        assert_equal "123", apple_show.apple_id
        assert_equal "bar", apple_show.apple_attributes["foo"]
      end
    end

    it "creates a sync log if one does not exist" do
      apple_show.api.stub(:get, OpenStruct.new(body: {"data" => {"id" => "123", "attributes" => {"foo" => "bar"}}}.to_json, code: "200")) do
        assert apple_show.sync_log.present?

        sync = apple_show.sync!

        assert_equal "123", sync.external_id
        assert_equal "123", apple_show.apple_id
        assert_equal "bar", apple_show.apple_attributes["foo"]
      end
    end

    it "logs an incomplete sync record if the upsert fails" do
      raises_exception = ->(_arg) { raise Apple::ApiError.new("Error", OpenStruct.new(code: 200, body: "body")) }

      apple_show.sync_log.destroy
      apple_show.public_feed.reload

      apple_show.stub(:create_or_update_show, raises_exception) do
        assert_raises(Apple::ApiError) do
          apple_show.sync!
        end
        assert_nil apple_show.sync_log
      end
    end
  end

  describe "#get_show" do
    it "raises an error if called without an apple_id" do
      assert_raises(RuntimeError) do
        apple_show.stub(:apple_id, nil) do
          apple_show.get_show
        end
      end
    end
  end

  describe "#show_data" do
    it "returns a hash" do
      assert_equal apple_show.show_data({}).class, Hash
    end
  end

  describe "#feed_published_url" do
    before do
      public_feed.podcast.feeds.update_all(private: true)
      public_feed.podcast.feeds.map { |f| f.tokens.build(label: "my-tok").save! }
      apple_show.podcast.reload
      public_feed.reload
      private_feed.reload
    end

    it "returns an authed url if private" do
      assert_equal apple_show.feed_published_url,
        "https://p.prxu.org/#{public_feed.podcast.path}/feed-rss.xml?auth=" + public_feed.tokens.first.token
    end

    it "raises an error when there is no token" do
      # a private feed with no tokens
      podcast.feeds.map { |f| f.tokens.delete_all }
      apple_show.podcast.reload

      assert_raise(RuntimeError) do
        apple_show.feed_published_url
      end
    end
  end

  describe "#guid_to_apple_json" do
    it "should memoize the guid_to_apple_json without calling apple_episode_json" do
      data = {"foo" => "bar"}

      apple_show.instance_variable_set(:@guid_to_apple_json, data)

      mock = Minitest::Mock.new
      def mock.method_missing(*)
        raise "apple_episode_json should not have been called!"
      end

      apple_show.stub(:apple_episode_json, mock) do
        assert_equal "bar", apple_show.guid_to_apple_json("foo")
      end
    end

    it "falls back to apple_episode_json when not memoized" do
      apple_show.reload

      data = {"attributes" => {"guid" => "foo", "data" => "frob"}}
      apple_show.stub(:apple_episode_json, [data]) do
        assert_equal apple_show.guid_to_apple_json("foo"), {"attributes" => {"guid" => "foo", "data" => "frob"}}
      end
    end
  end
end
