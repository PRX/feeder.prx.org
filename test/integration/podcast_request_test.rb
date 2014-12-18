require 'test_helper'
require 'nokogiri'

describe 'RSS feed Integration Test' do
  before :each do
    @podcast = create(:podcast, :with_images)
    @channel_image = @podcast.channel_image
    @itunes_image = @podcast.itunes_image
    @episodes = create_list(:episode, 2, podcast: @podcast)
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
    @feed.at_css('pubDate').text.must_equal @podcast.pub_date.strftime('%a, %d %b %Y %H:%M:%S %Z')
    @feed.css('lastBuildDate').text.must_equal @podcast.last_build_date.strftime('%a, %d %b %Y %H:%M:%S %Z')
    @feed.css('atom|link').text.must_equal "/podcasts/#{@podcast.id}"
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

  it 'displays correct episode info' do
    @feed.css('item').each_with_index do |node, i|
      node.css('title').text.must_equal @episodes[i].title
    end
  end
end
