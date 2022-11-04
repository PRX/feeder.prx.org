# frozen_string_literal: true

require "test_helper"

describe Apple::Show do
  let(:podcast) { create(:podcast) }
  let(:feed) { create(:feed, podcast: podcast, private: false) }
  let(:apple_show) { Apple::Show.new(feed) }

  before do
    stub_request(:get, "https://api.podcastsconnect.apple.com/v1/countriesAndRegions?limit=200").
      to_return(status: 200, body: json_file(:apple_countries_and_regions), headers: {})
  end

  describe ".connect_existing" do
    it "should persist the apple id for a feed" do
      Apple::Show.connect_existing(feed, "some_apple_id")

      assert_equal Apple::Show.new(feed).apple_id, "some_apple_id"
    end
  end

  describe "#id" do
    it "should return nil if not set" do
      assert_nil apple_show.apple_id
    end
  end

  describe "#sync!" do
    it "runs sync!" do
      apple_show.stub(:create_or_update_show, { "data" => { "id" => "123" } }) do
        sync = apple_show.sync!

        assert_equal sync.class, SyncLog
        assert_equal sync.complete?, true
      end
    end

    it "logs an incomplete sync record if the upsert fails" do
      raises_exception = ->(arg) { raise Apple::ApiError.new(arg) }
      apple_show.stub(:create_or_update_show, raises_exception) do
        sync = apple_show.sync!

        assert_equal sync.complete?, false
      end
    end
  end

  describe "#get_show" do
    it "raises an error if called without an apple_id" do
      assert_raises(RuntimeError) do
        apple_show.get_show
      end
    end
  end

  describe "#show_data" do
    it "returns a hash" do
      assert_equal apple_show.show_data.class, Hash
    end
  end

  describe "#feed_published_url" do
    before do
      feed.podcast.feeds.update_all(private: true)
      feed.podcast.feeds.map { |f| f.tokens.build.save! }
      apple_show.podcast.reload
    end

    it "returns an authed url if private" do
      assert_equal apple_show.feed_published_url,
                   feed.podcast.published_url + "?auth=#{podcast.default_feed.tokens.first.token}"
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
