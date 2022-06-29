# frozen_string_literal: true

require 'test_helper'

describe Apple::Show do

  let(:podcast) { create(:podcast) }
  let(:feed) { create(:feed, podcast: podcast, private: false) }
  let(:apple_show) { Apple::Show.new(feed) }

  before do
   stub_request(:get, 'https://api.podcastsconnect.apple.com/v1/countriesAndRegions?limit=200').
     to_return(status: 200, body: json_file(:apple_countries_and_regions), headers: {})
  end

  describe '#sync!' do
    it 'runs sync!' do

      apple_show.stub(:create_or_update_show, {'data' => {'id' => '123'}}) do

        sync = apple_show.sync!

        assert_equal sync.class, SyncLog
        assert_equal sync.complete?, true
      end
    end

    it 'logs an incomplete sync record if the upsert fails' do
      raises_exception = -> (arg) { raise Apple::ApiError.new(arg) }
      apple_show.stub(:create_or_update_show, raises_exception) do
        sync = apple_show.sync!

        assert_equal sync.complete?, false
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
      feed.update!(private: true)
      feed.tokens.build.save!
    end

    it 'returns an authed url if private' do
      assert_equal apple_show.feed_published_url, feed.published_url + "?auth=#{feed.tokens.first.token}"
    end

    it 'raises an error when there is no token' do
      feed.tokens.delete_all

      assert_raise(RuntimeError) { apple_show.feed_published_url}
    end
  end
end
