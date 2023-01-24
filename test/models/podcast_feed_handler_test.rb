require "test_helper"
require "prx_access"

describe PodcastFeedHandler do
  include PrxAccess

  let(:entry) { api_resource(JSON.parse(json_file(:crier_entry)), crier_root) }
  let(:feed) { entry.objects["prx:feed"] }

  before {
    stub_request(:get, "http://serialpodcast.org/sites/all/modules/custom/serial/img/serial-itunes-logo.png")
      .to_return(status: 200, body: test_file("/fixtures/transistor1400.jpg"), headers: {})
  }

  it "create_from_feed" do
    podcast = PodcastFeedHandler.create_from_feed!(feed)

    refute_nil podcast.id
    refute_nil podcast.created_at
    refute_nil podcast.updated_at
    assert_nil podcast.prx_uri
    assert_nil podcast.deleted_at
    assert_equal podcast.title, "Serial"
    assert_equal podcast.source_url, "https://s3.amazonaws.com/prx-dovetail/testserial/serialpodcast.xml"
    assert_equal podcast.link, "http://serialpodcast.org"
    assert_equal podcast.author_name, "This American Life"
    assert_nil podcast.owner_name
    assert_equal podcast.owner_email, "rich@strangebirdlabs.com"
    assert_equal podcast.managing_editor_name, "This American Life"
    assert_equal podcast.managing_editor_email, "chad@thislife.org"
    assert_equal podcast.new_feed_url, "https://s3.amazonaws.com/prx-dovetail/testserial/newserialpodcast.xml"
  end

  it "update_from_feed" do
    podcast = Podcast.new
    PodcastFeedHandler.update_from_feed!(podcast, feed)

    assert_equal podcast.title, "Serial"
    assert_equal podcast.source_url, "https://s3.amazonaws.com/prx-dovetail/testserial/serialpodcast.xml"
    assert_equal podcast.link, "http://serialpodcast.org"
    assert_equal podcast.author_name, "This American Life"
    assert_nil podcast.owner_name
    assert_equal podcast.owner_email, "rich@strangebirdlabs.com"
    assert_equal podcast.managing_editor_name, "This American Life"
    assert_equal podcast.managing_editor_email, "chad@thislife.org"
    assert_equal podcast.new_feed_url, "https://s3.amazonaws.com/prx-dovetail/testserial/newserialpodcast.xml"
  end

  it "update_images" do
    feed = OpenStruct.new(
      attributes: {
        thumb_url: "http://prx.org/thumb.png",
        image_url: "http://prx.org/image.png"
      }
    )
    podcast = Podcast.new
    handler = PodcastFeedHandler.new(podcast)
    handler.feed = feed

    handler.update_images

    assert_equal handler.default_feed.feed_images.first.original_url, "http://prx.org/thumb.png"
    assert_equal handler.default_feed.itunes_images.first.original_url, "http://prx.org/image.png"
  end

  it "update_categories" do
    feed = OpenStruct.new(
      categories: ["Science", "Natural Sciences", "Fictional"]
    )
    podcast = Podcast.new
    handler = PodcastFeedHandler.new(podcast)
    handler.feed = feed

    handler.update_categories

    assert_equal podcast.itunes_categories.size, 1
    assert_equal podcast.itunes_categories.first.name, "Science"
    assert_equal podcast.categories.first, "Fictional"
  end
end
