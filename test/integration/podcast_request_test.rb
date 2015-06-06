require 'test_helper'
require 'nokogiri'

describe 'RSS feed Integration Test' do
  before do
    stub_requests_to_prx_cms

    Podcast.delete_all
    Episode.delete_all

    @podcast = create(:podcast)
    @channel_image = @podcast.feed_image
    @itunes_image = @podcast.itunes_image
    @episodes = create_list(:episode, 1, podcast: @podcast, prx_id: 87683).reverse
    @category = create(:itunes_category, podcast: @podcast)

    get "/podcasts/#{@podcast.id}"
    @feed = Nokogiri::XML(response.body).css('channel')
  end

  it 'returns an rss feed with correct podcast information' do
    response.status.must_equal 200
    response.content_type.to_s.must_equal 'application/rss+xml'

    @feed.at_css('link').text.must_equal @podcast.link
    @feed.at_css('title').text.must_equal @podcast.title
    @feed.css('language').text.must_equal @podcast.language
    @feed.at_css('description').text.must_equal @podcast.description
    @feed.css('copyright').text.must_equal @podcast.copyright
    @feed.css('managingEditor').text.must_equal @podcast.managing_editor
    @feed.at_css('pubDate').text.must_equal @podcast.pub_date.rfc2822
    @feed.css('lastBuildDate').text.must_equal @podcast.last_build_date.rfc2822
    @feed.at_css('atom|link').attributes['href'].value.must_equal 'http://feeds.feedburner.com/thornmorris'
    @feed.at_css('itunes|author').text.must_equal @podcast.author
    @feed.at_css('itunes|explicit').text.must_equal 'yes'
  end

  it 'contains correct podcast image information' do
    image_xml = @feed.css('image')

    image_xml.css('url').text.must_equal @channel_image.url
    image_xml.css('title').text.must_equal @channel_image.title
    image_xml.css('link').text.must_equal @channel_image.link
    image_xml.css('width').text.must_equal @channel_image.width.to_s
    image_xml.css('height').text.must_equal @channel_image.height.to_s
    image_xml.css('description').text.must_equal @channel_image.description
  end

  it 'displays iTunes categories correctly' do
    cat_node = @feed.at_css('itunes|category')
    subcats = @category.subcategories.split(', ')

    cat_node.attributes['text'].value.must_equal @category.name
    cat_node.element_children[0].attributes['text'].value.must_equal subcats[0]
    cat_node.element_children[1].attributes['text'].value.must_equal subcats[1]
  end

  it 'displays correct episode titles' do
    @feed.css('item').each_with_index do |node, i|
      title = JSON.parse(@episodes[i].overrides)['title']
      node.css('title').text.must_equal title
    end
  end

  it 'displays plaintext and richtext descriptions' do
    node = @feed.css('item')[0]
    node.css('description').text.strip[0..3].must_equal "Tina"
    node.css('content|encoded').text.strip[0..4].must_equal "<div>"
  end
end
