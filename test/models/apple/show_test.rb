# frozen_string_literal: true

require "test_helper"

describe Apple::Show do
  let(:podcast) { create(:episode).podcast }
  let(:apple_api) { Apple::Api.from_apple_config(apple_config) }
  let(:public_feed) { create(:feed, podcast: podcast, private: false) }
  let(:private_feed) { create(:private_feed, podcast: podcast) }
  let(:apple_config) { build(:apple_config, public_feed: public_feed, private_feed: private_feed) }
  let(:apple_show) { Apple::Show.connect_existing("123", apple_config) }

  before do
    stub_request(:get, "https://api.podcastsconnect.apple.com/v1/countriesAndRegions?limit=200")
      .to_return(status: 200, body: json_file(:apple_countries_and_regions), headers: {})
  end

  describe "#reload" do
    it "flushes memoized attrs" do
      apple_show.instance_variable_set(:@apple_episode_json, "foo")
      apple_show.instance_variable_set(:@podcast_feeder_episodes, "foo")
      apple_show.instance_variable_set(:@episodes, "foo")
      apple_show.reload
      assert_nil apple_show.instance_variable_get(:@apple_episode_json)
      assert_nil apple_show.instance_variable_get(:@podcast_feeder_episodes)
      assert_nil apple_show.instance_variable_get(:@episodes)
    end

    it "doesn't raise an error if the attr isn't memoized" do
      apple_show.reload
    end

    it "doesn't raise an error if the attr is nil" do
      apple_show.instance_variable_set(:@apple_episode_json, nil)
      apple_show.instance_variable_set(:@podcast_feeder_episodes, nil)
      apple_show.instance_variable_set(:@episodes, nil)
      apple_show.reload
      assert_nil apple_show.instance_variable_get(:@podcast_feeder_episodes)
      assert_nil apple_show.instance_variable_get(:@apple_episode_json)
      assert_nil apple_show.instance_variable_get(:@episodes)
    end

    it "doesn't raise an error if the attr is false" do
      apple_show.instance_variable_set(:@apple_episode_json, false)
      apple_show.instance_variable_set(:@podcast_feeder_episodes, false)
      apple_show.instance_variable_set(:@episodes, false)
      apple_show.reload
      assert_nil apple_show.instance_variable_get(:@podcast_feeder_episodes)
      assert_nil apple_show.instance_variable_get(:@apple_episode_json)
      assert_nil apple_show.instance_variable_get(:@episodes)
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
  end

  describe ".connect_existing" do
    let(:apple_config) { create(:apple_config, public_feed: public_feed, private_feed: private_feed) }

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
        sync = nil
        assert_raises(Apple::ApiError) do
          sync = apple_show.sync!
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
        "https://p.prxu.org/#{public_feed.podcast.path}/#{public_feed.slug}/feed-rss.xml?auth=" + public_feed.tokens.first.token
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
end
