require 'test_helper'
require 'feed_builder'

describe FeedBuilder do

  let(:episode) { create(:episode, prx_uri: "/api/v1/stories/87683") }
  let(:podcast) { episode.podcast }
  let(:raw_feed) { create(:feed, podcast: podcast, overrides: { title: 'feed override' } ) }
  let(:feed) { FeedDecorator.new(raw_feed) }
  let(:builder) { FeedBuilder.new(feed) }

  it 'can load the rss template' do
    template = builder.rss_template
    template.wont_be_nil
    template[0,12].must_equal 'xml.instruct'
  end

  it 'can setup the data based on the podcast' do
    builder.podcast.must_equal feed
    builder.podcast.feed.must_equal raw_feed
    builder.podcast.feed.podcast.must_equal podcast
    builder.episodes.count.must_equal 1
  end

  it 'can setup the data based on a decorated feed' do
    rss = builder.to_feed_xml
    rss.wont_be_nil
    rss[0, 38].must_equal '<?xml version="1.0" encoding="UTF-8"?>'
    # puts "------rss start--------"
    # puts rss
    # puts "-------rss end---------"
  end

  it 'can setup the data based on a decorated feed' do
    builder = FeedBuilder.new(podcast)
    rss = builder.to_feed_xml
    rss.wont_be_nil
    rss[0, 38].must_equal '<?xml version="1.0" encoding="UTF-8"?>'
    # puts "------rss start--------"
    # puts rss
    # puts "-------rss end---------"
  end
end
