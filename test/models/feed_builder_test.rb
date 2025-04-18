require "test_helper"
require "feed_builder"

describe FeedBuilder do
  let(:transcript) { create(:transcript) }
  let(:episode) { create(:episode_with_media, prx_uri: "/api/v1/stories/87683", transcript: transcript) }
  let(:podcast) { episode.podcast }
  let(:feed) { create(:feed, podcast: podcast, title: podcast.title, private: false, unique_guids: true) }
  let(:builder) { FeedBuilder.new(podcast, feed) }
  let(:rss) { builder.to_feed_xml }
  let(:rss_feed) { Nokogiri::XML(rss).css("channel") }

  it "can load the rss template" do
    template = builder.rss_template
    _(template).wont_be_nil
    _(template[0, 12]).must_equal "xml.instruct"
  end

  it "can setup the data based on the podcast" do
    feed.set_default_episodes
    _(builder.podcast).must_equal podcast
    _(builder.feed).must_equal feed
    _(builder.episodes.count).must_equal 1
  end

  it "can setup the data based on a decorated feed" do
    rss = builder.to_feed_xml
    _(rss).wont_be_nil
    _(rss[0, 38]).must_equal '<?xml version="1.0" encoding="UTF-8"?>'
  end

  it "can setup the data based on a podcast and default feed" do
    builder = FeedBuilder.new(podcast)
    rss = builder.to_feed_xml
    _(rss).wont_be_nil
    _(rss[0, 38]).must_equal '<?xml version="1.0" encoding="UTF-8"?>'
  end

  it "returns an rss feed with correct podcast information" do
    assert_equal rss_feed.at_css("link").text, podcast.link
    assert_equal rss_feed.at_css("title").text, podcast.title
    assert_equal rss_feed.css("language").text, podcast.language
    assert_equal rss_feed.at_css("description").text.strip, podcast.description
    assert_equal rss_feed.css("copyright").text, podcast.copyright
    assert_equal rss_feed.css("managingEditor").text, podcast.managing_editor
    assert_equal rss_feed.at_css("pubDate").text, podcast.pub_date.utc.rfc2822
    assert_equal rss_feed.css("lastBuildDate").text, podcast.last_build_date.utc.rfc2822
    assert_equal rss_feed.at_css("atom|link").attributes["href"].value, "http://feeds.feedburner.com/thornmorris"
    assert_equal rss_feed.at_css("itunes|author").text, podcast.author_name
    assert_equal rss_feed.at_css("itunes|explicit").text, "true"
    assert_equal rss_feed.at_css("itunes|new-feed-url").text, "http://feeds.feedburner.com/newthornmorris"
  end

  it "contains correct podcast image information" do
    image_xml = rss_feed.css("image")

    assert_equal image_xml.css("url").text, podcast.feed_image.url
    assert_equal image_xml.css("title").text, podcast.title
    assert_equal image_xml.css("link").text, podcast.link
    assert_equal image_xml.css("width").text, podcast.feed_image.width.to_s
    assert_equal image_xml.css("height").text, podcast.feed_image.height.to_s
    assert_equal image_xml.css("description").text, podcast.subtitle
  end

  it "displays default feed iTunes categories" do
    cat_node = rss_feed.at_css("itunes|category")
    assert_equal cat_node.attributes["text"].value, "Leisure"
    assert_equal cat_node.element_children[0].attributes["text"].value, "Aviation"
    assert_equal cat_node.element_children[1].attributes["text"].value, "Automotive"
  end

  it "displays sub-feed iTunes categories" do
    create(:itunes_category, feed: feed, name: "Arts", subcategories: ["Books"])

    cat_node = rss_feed.at_css("itunes|category")
    assert_equal cat_node.attributes["text"].value, "Arts"
    assert_equal cat_node.element_children[0].attributes["text"].value, "Books"
  end

  it "displays correct episode titles" do
    feed.set_default_episodes
    rss_feed.css("item").each_with_index do |node, _i|
      assert_match(/Episode \d+/, node.css("title").text)
      assert_equal node.at_css("enclosure").attributes["length"].value, "774059"
      assert_equal node.css("itunes|duration").text, "0:48"
    end
  end

  it "creates a unique guid for the episode" do
    feed.set_default_episodes
    node = rss_feed.css("item")[0]
    assert_equal node.css("guid").text, "prx_#{podcast.id}_#{episode.guid}_#{feed.id}"
  end

  it "displays plaintext and richtext descriptions" do
    feed.set_default_episodes
    node = rss_feed.css("item")[0]
    assert_equal node.css("description").text.strip[0..4], "<div>"
    assert_equal node.css("itunes|summary").text.strip[0..6], "<a href"
  end

  it "contains itunes block yes when podcast itunes_block true" do
    builder = FeedBuilder.new(podcast)
    refute_match(/itunes:block/, builder.to_feed_xml)

    podcast.update_attribute(:itunes_block, true)
    assert_match(/itunes:block>Yes/, builder.to_feed_xml)
  end

  it "returns limited number of episodes" do
    create_list(:episode, 3, podcast: podcast)
    feed.set_default_episodes
    feed.update(display_episodes_count: 1)
    assert_equal rss_feed.css("item").count, 1
  end

  it "returns episodes wih minimal tags" do
    create_list(:episode, 3, podcast: podcast)
    feed.set_default_episodes
    feed.update(display_full_episodes_count: 1)
    assert_equal rss_feed.css("item").count, 4
    assert_equal rss_feed.xpath("//item/itunes:author").count, 1
  end

  it "defaults owner to author if owner email not set" do
    podcast.update(owner_email: "")
    assert_equal rss_feed.at_css("itunes|owner").css("itunes|email").text, podcast.author_email
    assert_equal rss_feed.at_css("itunes|owner").css("itunes|name").text, podcast.author_name
  end

  it "supports iTunes tags new in iOS11" do
    create_list(:episode, 3, podcast: podcast)

    podcast.update(serial_order: false)
    podcast.episodes.each_with_index do |e, i|
      e.update!(
        season_number: i + 1,
        episode_number: i + 1,
        title: "Season #{i + 1} Episode #{i + 1} Stripped-down title",
        clean_title: "Stripped-down title"
      )
    end

    assert_equal rss_feed.at_css("itunes|type").text, podcast.itunes_type

    rss_feed.css("item").each_with_index do |node, ind|
      assert_match(/Season \d+ Episode \d+/, node.css("title").text)
      assert_equal node.css("itunes|title").text, "Stripped-down title"
      assert_equal node.css("itunes|season").text.to_i, ind + 1
      assert_equal node.css("itunes|episode").text.to_i, ind + 1
      assert_match("full", node.css("itunes|episodeType").text)
    end
  end

  describe "with a guest author" do
    before do
      feed.set_default_episodes
    end

    it "displays correct podcast and episode author names" do
      episode.update!(author_name: "Foo Bar", author_email: "foo@bar.com")

      assert_equal rss_feed.at_css("itunes|author").text, podcast.author_name
      assert_equal rss_feed.at_css("item").css("itunes|author").text, episode.author_name
      assert_equal rss_feed.at_css("item").css("author").text, "#{episode.author_email} (#{episode.author_name})"
    end

    it "does not display episode author without email" do
      episode.update!(author_name: "Foo Bar", author_email: nil)
      podcast.update!(author_email: "")

      assert_equal rss_feed.at_css("item").css("author").count, 0
    end

    it "defaults episode author to podcast author if ep author email not set" do
      episode.update!(author_name: "Foo Bar")

      assert_equal rss_feed.at_css("item").css("author").count, 1
      assert_equal rss_feed.at_css("item").css("author").text, "#{podcast.author_email} (#{podcast.author_name})"
    end
  end

  describe "payment pointer" do
    let(:rss) { builder.to_feed_xml }
    let(:rss_feed) { Nokogiri::XML(rss).css("channel") }
    let(:value_recipient) { rss_feed.css("podcast|value").css("podcast|valueRecipient") }

    before do
      feed.set_default_episodes
    end

    it "contains payment pointer tag" do
      rss = builder.to_feed_xml
      _(rss).must_include "<podcast:value"
    end

    it "does not contain payment_pointer tag if feed.include_podcast_value is false" do
      feed.include_podcast_value = false
      rss = builder.to_feed_xml
      _(rss).wont_include "<podcast:value"
    end

    it "contains payment pointer recipient name" do
      name = value_recipient.attribute("name").to_s
      _(name).must_equal("Jesse Thorn")
    end

    it "contains payment pointer address" do
      address = value_recipient.attribute("address").to_s
      _(address).must_equal("$alice.example.pointer")
    end
  end

  describe "donation url" do
    let(:podcast_funding) { rss_feed.css("podcast|funding") }

    before do
      feed.set_default_episodes
    end

    it "contains funding tag" do
      rss = builder.to_feed_xml
      _(rss).must_include "<podcast:funding"
    end

    it "does not contain funding tag if feed.include_donation_url is false" do
      feed.include_donation_url = false
      rss = builder.to_feed_xml
      _(rss).wont_include "<podcast:funding"
    end

    it "includes donation url" do
      url = podcast_funding.attribute("url").to_s
      _(url).must_equal("https://prx.org/donations")
    end

    it "includes donation text" do
      text = podcast_funding.text
      _(text).must_equal("Support the Show!")
    end
  end

  it "displays the transcript attributes" do
    feed.set_default_episodes
    podcast_transcript = rss_feed.css("podcast|transcript")

    rss = builder.to_feed_xml
    _(rss).must_include "<podcast:transcript"

    url = podcast_transcript.attribute("url").to_s
    _(url).must_equal("http://some.where/test/fixtures/sampletranscript.html")

    type = podcast_transcript.attribute("type").to_s
    _(type).must_equal("text/html")
  end
end
