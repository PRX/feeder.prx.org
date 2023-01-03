# frozen_string_literal: true

require 'test_helper'

describe Apple::Show do
  let(:podcast) { create(:podcast) }
  let(:apple_creds) { build(:apple_credential) }
  let(:apple_api) { Apple::Api.from_apple_credentials(apple_creds) }
  let(:public_feed) { create(:feed, podcast: podcast, private: false) }
  let(:private_feed) { create(:feed, podcast: podcast, private: true) }
  let(:apple_show) { Apple::Show.new(api: apple_api, public_feed: public_feed, private_feed: private_feed) }

  before do
    stub_request(:get, 'https://api.podcastsconnect.apple.com/v1/countriesAndRegions?limit=200').
      to_return(status: 200, body: json_file(:apple_countries_and_regions), headers: {})
  end

  describe '#reload' do
    it 'flushes memoized attrs' do
      apple_show.instance_variable_set(:@get_episodes_json, 'foo')
      apple_show.reload
      assert_nil apple_show.instance_variable_get(:@get_episodes_json)
    end

    it "doesn't raise an error if the attr isn't memoized" do
      apple_show.reload
    end

    it "doesn't raise an error if the attr is nil" do
      apple_show.instance_variable_set(:@get_episodes_json, nil)
      apple_show.reload
      assert_nil apple_show.instance_variable_get(:@get_episodes_json)
    end

    it "doesn't raise an error if the attr is false" do
      apple_show.instance_variable_set(:@get_episodes_json, false)
      apple_show.reload
      assert_nil apple_show.instance_variable_get(:@get_episodes_json)
    end
  end

  describe '.connect_existing' do
    it 'should persist the apple id for a feed' do
      Apple::Show.connect_existing('some_apple_id', apple_api, public_feed, private_feed)

      assert_equal Apple::Show.new(api: apple_api, public_feed: public_feed, private_feed: private_feed).apple_id,
                   'some_apple_id'
    end
  end

  describe '#apple_id' do
    it 'should return nil if not set' do
      assert_nil apple_show.apple_id
    end
  end

  describe '#sync!' do
    it 'runs sync!' do
      apple_show.stub(:create_or_update_show, { 'data' => { 'id' => '123' } }) do
        sync = apple_show.sync!

        assert_equal sync.class, SyncLog
        assert_equal sync.complete?, true
      end
    end

    it 'logs an incomplete sync record if the upsert fails' do
      raises_exception = ->(_arg) { raise Apple::ApiError.new('Error', OpenStruct.new(code: 200, body: 'body')) }
      apple_show.stub(:create_or_update_show, raises_exception) do
        sync = nil
        assert_raises(Apple::ApiError) do
          sync = apple_show.sync!
        end
        assert_nil apple_show.completed_sync_log
      end
    end
  end

  describe '#get_show' do
    it 'raises an error if called without an apple_id' do
      assert_raises(RuntimeError) do
        apple_show.get_show
      end
    end
  end

  describe '#show_data' do
    it 'returns a hash' do
      assert_equal apple_show.show_data.class, Hash
    end
  end

  describe '#feed_published_url' do
    before do
      public_feed.podcast.feeds.update_all(private: true)
      public_feed.podcast.feeds.map { |f| f.tokens.build.save! }
      apple_show.podcast.reload
      public_feed.reload
      private_feed.reload
    end

    it 'returns an authed url if private' do
      assert_equal apple_show.feed_published_url,
                   "https://p.prxu.org/jjgo/#{public_feed.slug}/feed-rss.xml?auth=" + public_feed.tokens.first.token
    end

    it 'raises an error when there is no token' do
      # a private feed with no tokens
      podcast.feeds.map { |f| f.tokens.delete_all }
      apple_show.podcast.reload

      assert_raise(RuntimeError) do
        apple_show.feed_published_url
      end
    end
  end
end
