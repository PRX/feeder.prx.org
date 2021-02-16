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
    assert_equal response.status, 200
    assert_equal response.content_type.to_s, 'application/rss+xml'

    assert_equal @feed.at_css('link').text, @podcast.link
    assert_equal @feed.at_css('title').text, @podcast.title
    assert_equal @feed.css('language').text, @podcast.language
    assert_equal @feed.at_css('description').text.strip, @podcast.description
    assert_equal @feed.css('copyright').text, @podcast.copyright
    assert_equal @feed.css('managingEditor').text, @podcast.managing_editor
    assert_equal @feed.at_css('pubDate').text, @podcast.pub_date.utc.rfc2822
    assert_equal @feed.css('lastBuildDate').text, @podcast.last_build_date.utc.rfc2822
    assert_equal @feed.at_css('atom|link').attributes['href'].value, 'http://feeds.feedburner.com/thornmorris'
    assert_equal @feed.at_css('itunes|author').text, @podcast.author_name
    assert_equal @feed.at_css('itunes|explicit').text, 'true'
    assert_equal @feed.at_css('itunes|new-feed-url').text, 'http://feeds.feedburner.com/newthornmorris'
  end

  it 'contains correct podcast image information' do
    image_xml = @feed.css('image')

    assert_equal image_xml.css('url').text, @channel_image.url
    assert_equal image_xml.css('title').text, @channel_image.title
    assert_equal image_xml.css('link').text, @channel_image.link
    assert_equal image_xml.css('width').text, @channel_image.width.to_s
    assert_equal image_xml.css('height').text, @channel_image.height.to_s
    assert_equal image_xml.css('description').text, @channel_image.description
  end

  it 'displays iTunes categories correctly' do
    cat_node = @feed.at_css('itunes|category')
    subcats = @category.subcategories

    assert_equal cat_node.attributes['text'].value, @category.name
    assert_equal cat_node.element_children[0].attributes['text'].value, subcats[0]
    assert_equal cat_node.element_children[1].attributes['text'].value, subcats[1]
  end

  it 'displays correct episode titles' do
    @feed.css('item').each_with_index do |node, i|
      assert_match(/Episode \d+/, node.css('title').text)
      assert_equal node.at_css('enclosure').attributes['length'].value, '774059'
      assert_equal node.css('itunes|duration').text, '0:48'
    end
  end

  it 'displays plaintext and richtext descriptions' do
    node = @feed.css('item')[0]
    assert_equal node.css('description').text.strip[0..4], "<div>"
    assert_equal node.css('itunes|summary').text.strip[0..6], "<a href"
  end

  it 'returns limited number of episodes' do
    @podcast.update_attributes(display_episodes_count: 1)
    get "/podcasts/#{@podcast.id}"
    @feed = Nokogiri::XML(response.body).css('channel')
    assert_equal @feed.css('item').count, 1
  end

  it 'returns episodes wih minimal tags' do
    @podcast.update_attributes(display_full_episodes_count: 1)
    get "/podcasts/#{@podcast.id}"
    @feed = Nokogiri::XML(response.body).css('channel')
    assert_equal @feed.xpath('//item/itunes:author').count, 1
  end

  it 'defaults owner to author if owner email not set' do
    @podcast.update_attributes(owner_email: '')
    get "/podcasts/#{@podcast.id}"
    assert_equal @feed.at_css('itunes|owner').css('itunes|email').text, @podcast.author_email
    assert_equal @feed.at_css('itunes|owner').css('itunes|name').text, @podcast.author_name
  end

  it 'supports iTunes tags new in iOS11' do
    @episodes.each_with_index do |e, i|
      e.update_attributes(season_number: i + 1,
                          episode_number: i + 1,
                          title: 'Season 2 Episode 3 Stripped-down title',
                          clean_title: 'Stripped-down title')
    end
    @podcast.update_attributes(serial_order: false)
    get "/podcasts/#{@podcast.id}"
    @feed = Nokogiri::XML(response.body).css('channel')

    assert_equal @feed.at_css('itunes|type').text, @podcast.itunes_type
    @feed.css('item').reverse.each_with_index do |node, ind|
      assert_match(/Season \d+ Episode \d+/, node.css('title').text)
      assert_equal node.css('itunes|title').text, "Stripped-down title"
      assert_equal node.css('itunes|season').text.to_i, ind + 1
      assert_equal node.css('itunes|episode').text.to_i, ind + 1
      assert_match('full', node.css('itunes|episodeType').text)
    end
  end

  describe 'with a guest author' do
    before do
      @podcast.episodes.destroy_all
    end

    it 'displays correct podcast and episode author names' do
      @ep = create(:episode, podcast: @podcast, author_name: 'Foo Bar', author_email: 'foo@bar.com')
      get "/podcasts/#{@podcast.id}"
      @feed = Nokogiri::XML(response.body).css('channel')

      assert_equal @feed.at_css('itunes|author').text, @podcast.author_name
      assert_equal @feed.at_css('item').css('itunes|author').text, @ep.author_name
      assert_equal @feed.at_css('item').css('author').text, "#{@ep.author_email} (#{@ep.author_name})"
    end

    it 'does not display episode author without email' do
      @ep = create(:episode, podcast: @podcast, author_name: 'Foo Bar')
      @podcast.update_attributes(author_email: '')
      get "/podcasts/#{@podcast.id}"
      @feed = Nokogiri::XML(response.body).css('channel')
      assert_equal @feed.at_css('item').css('author').count, 0
    end

    it 'defaults episode author to podcast author if ep author email not set' do
      @ep = create(:episode, podcast: @podcast, author_name: 'Foo Bar')
      get "/podcasts/#{@podcast.id}"
      @feed = Nokogiri::XML(response.body).css('channel')
      assert_equal @feed.at_css('item').css('author').count, 1
      assert_equal @feed.at_css('item').css('author').text, "#{@podcast.author_email} (#{@podcast.author_name})"
    end
  end
end
