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
    @episodes = create_list(:episode, 4, podcast: @podcast).reverse
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
    @feed.at_css('description').text.strip.must_equal @podcast.description
    @feed.css('copyright').text.must_equal @podcast.copyright
    @feed.css('managingEditor').text.must_equal @podcast.managing_editor
    @feed.at_css('pubDate').text.must_equal @podcast.pub_date.utc.rfc2822
    @feed.css('lastBuildDate').text.must_equal @podcast.last_build_date.utc.rfc2822
    @feed.at_css('atom|link').attributes['href'].value.must_equal 'http://feeds.feedburner.com/thornmorris'
    @feed.at_css('itunes|author').text.must_equal @podcast.author_name
    @feed.at_css('itunes|explicit').text.must_equal 'yes'
    @feed.at_css('itunes|new-feed-url').text.must_equal 'http://feeds.feedburner.com/newthornmorris'
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
    subcats = @category.subcategories

    cat_node.attributes['text'].value.must_equal @category.name
    cat_node.element_children[0].attributes['text'].value.must_equal subcats[0]
    cat_node.element_children[1].attributes['text'].value.must_equal subcats[1]
  end

  it 'displays correct episode titles' do
    @feed.css('item').each_with_index do |node, i|
      node.css('title').text.must_match /Episode \d+/
      node.at_css('enclosure').attributes['length'].value.must_equal '774059'
      node.css('itunes|duration').text.must_equal '0:48'
    end
  end

  it 'displays plaintext and richtext descriptions' do
    node = @feed.css('item')[0]
    node.css('description').text.strip[0..4].must_equal "<div>"
    node.css('itunes|summary').text.strip[0..6].must_equal "<a href"
  end

  it 'returns limited number of episodes' do
    @podcast.update_attributes(display_episodes_count: 1)
    get "/podcasts/#{@podcast.id}"
    @feed = Nokogiri::XML(response.body).css('channel')
    @feed.css('item').count.must_equal 1
  end

  it 'returns episodes wih minimal tags' do
    @podcast.update_attributes(display_full_episodes_count: 1)
    get "/podcasts/#{@podcast.id}"
    @feed = Nokogiri::XML(response.body).css('channel')
    @feed.xpath('//item/itunes:author').count.must_equal 1
  end

  it 'defaults owner to author if owner email not set' do
    @podcast.update_attributes(owner_email: '')
    get "/podcasts/#{@podcast.id}"
    @feed.at_css('itunes|owner').css('itunes|email').text.must_equal @podcast.author_email
    @feed.at_css('itunes|owner').css('itunes|name').text.must_equal @podcast.author_name
  end

  describe 'with a guest author' do
    before do
      @podcast.episodes.destroy_all
    end

    it 'displays correct podcast and episode author names' do
      @ep = create(:episode, podcast: @podcast, author_name: 'Foo Bar', author_email: 'foo@bar.com')
      get "/podcasts/#{@podcast.id}"
      @feed = Nokogiri::XML(response.body).css('channel')

      @feed.at_css('itunes|author').text.must_equal @podcast.author_name
      @feed.at_css('item').css('itunes|author').text.must_equal @ep.author_name
      @feed.at_css('item').css('author').text.must_equal "#{@ep.author_email} (#{@ep.author_name})"
    end

    it 'does not display episode author without email' do
      @ep = create(:episode, podcast: @podcast, author_name: 'Foo Bar')
      @podcast.update_attributes(author_email: '')
      get "/podcasts/#{@podcast.id}"
      @feed = Nokogiri::XML(response.body).css('channel')
      @feed.at_css('item').css('author').count.must_equal 0
    end

    it 'defaults episode author to podcast author if ep author email not set' do
      @ep = create(:episode, podcast: @podcast, author_name: 'Foo Bar')
      get "/podcasts/#{@podcast.id}"
      @feed = Nokogiri::XML(response.body).css('channel')
      @feed.at_css('item').css('author').count.must_equal 1
      @feed.at_css('item').css('author').text.must_equal "#{@podcast.author_email} (#{@podcast.author_name})"
    end
  end
end
