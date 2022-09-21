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

      podcast.default_feed.payment_pointer = nil
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
end
