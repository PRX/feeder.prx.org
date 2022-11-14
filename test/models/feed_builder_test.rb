require 'test_helper'
require 'feed_builder'

describe FeedBuilder do

  let(:episode) { create(:episode, prx_uri: "/api/v1/stories/87683") }
  let(:podcast) { episode.podcast }
  let(:feed) { create(:feed, podcast: podcast) }
  let(:builder) { FeedBuilder.new(podcast, feed) }

  it 'can load the rss template' do
    template = builder.rss_template
    _(template).wont_be_nil
    _(template[0,12]).must_equal 'xml.instruct'
  end

  it 'can setup the data based on the podcast' do
    _(builder.podcast).must_equal podcast
    _(builder.feed).must_equal feed
    _(builder.episodes.count).must_equal 1
  end

  it 'can setup the data based on a decorated feed' do
    rss = builder.to_feed_xml
    _(rss).wont_be_nil
    _(rss[0, 38]).must_equal '<?xml version="1.0" encoding="UTF-8"?>'
  end

  it 'can setup the data based on a podcast and default feed' do
    builder = FeedBuilder.new(podcast)
    rss = builder.to_feed_xml
    _(rss).wont_be_nil
    _(rss[0, 38]).must_equal '<?xml version="1.0" encoding="UTF-8"?>'
  end

  describe 'payment pointer' do
    let(:rss) { builder.to_feed_xml }
    let(:rss_feed) { Nokogiri::XML(rss).css('channel') }
    let(:value_recipient) { rss_feed.css('podcast|value').css('podcast|valueRecipient') }

    it 'contains payment pointer tag' do
      rss = builder.to_feed_xml
      _(rss).must_include '<podcast:value'
    end

    it 'does not contain payment_pointer tag if feed.include_podcast_value is false' do
      feed.include_podcast_value = false
      rss = builder.to_feed_xml
      _(rss).wont_include '<podcast:value'
    end

    it 'contains payment pointer recipient name' do
      name = value_recipient.attribute('name').to_s
      _(name).must_equal('Jesse Thorn')
    end

    it 'contains payment pointer address' do
      address = value_recipient.attribute('address').to_s
      _(address).must_equal('$alice.example.pointer')
    end
  end

  describe 'donation url' do
    let(:rss) { builder.to_feed_xml }
    let(:rss_feed) { Nokogiri::XML(rss).css('channel') }
    let(:podcast_funding) { rss_feed.css('podcast|funding') }

    it 'contains funding tag' do
      rss = builder.to_feed_xml
      _(rss).must_include '<podcast:funding'
    end

    it 'does not contain funding tag if feed.include_donation_url is false' do
      feed.include_donation_url = false
      rss = builder.to_feed_xml
      _(rss).wont_include '<podcast:funding'
    end

    it 'includes donation url' do
      url = podcast_funding.attribute('url').to_s
      _(url).must_equal('https://prx.org/donations')
    end

    it 'includes donation text' do
      text = podcast_funding.text
      _(text).must_equal('Support the Show!')
    end
  end
end
