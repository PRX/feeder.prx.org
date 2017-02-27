require 'test_helper'
require 'prx_access'

describe PodcastFeedHandler do
  include PRXAccess

  let (:entry) { api_resource(JSON.parse(json_file(:crier_entry)), crier_root) }
  let (:feed) { entry.objects['prx:feed'] }

  before {
    stub_request(:get, 'http://serialpodcast.org/sites/all/modules/custom/serial/img/serial-itunes-logo.png').
      to_return(status: 200, body: test_file('/fixtures/transistor1400.jpg'), headers: {})
  }

  it 'create_from_feed' do
    podcast = PodcastFeedHandler.create_from_feed!(feed)

    podcast.id.wont_be_nil
    podcast.created_at.wont_be_nil
    podcast.updated_at.wont_be_nil
    podcast.prx_uri.must_be_nil
    podcast.deleted_at.must_be_nil
    podcast.title.must_equal 'Serial'
    podcast.source_url.must_equal 'https://s3.amazonaws.com/prx-dovetail/testserial/serialpodcast.xml'
    podcast.link.must_equal 'http://serialpodcast.org'
    podcast.author_name.must_equal 'This American Life'
    podcast.owner_name.must_be_nil
    podcast.owner_email.must_equal 'rich@strangebirdlabs.com'
    podcast.managing_editor_name.must_equal 'This American Life'
    podcast.managing_editor_email.must_equal 'chad@thislife.org'
    podcast.new_feed_url.must_equal 'https://s3.amazonaws.com/prx-dovetail/testserial/newserialpodcast.xml'
  end

  it 'update_from_feed' do
    podcast = Podcast.new
    PodcastFeedHandler.update_from_feed!(podcast, feed)

    podcast.title.must_equal 'Serial'
    podcast.source_url.must_equal 'https://s3.amazonaws.com/prx-dovetail/testserial/serialpodcast.xml'
    podcast.link.must_equal 'http://serialpodcast.org'
    podcast.author_name.must_equal 'This American Life'
    podcast.owner_name.must_be_nil
    podcast.owner_email.must_equal 'rich@strangebirdlabs.com'
    podcast.managing_editor_name.must_equal 'This American Life'
    podcast.managing_editor_email.must_equal 'chad@thislife.org'
    podcast.new_feed_url.must_equal 'https://s3.amazonaws.com/prx-dovetail/testserial/newserialpodcast.xml'
  end

  it 'update_images' do
    feed = OpenStruct.new(
      attributes: {
        thumb_url: 'http://prx.org/thumb.png',
        image_url: 'http://prx.org/image.png'
      }
    )
    podcast = Podcast.new
    handler = PodcastFeedHandler.new(podcast)
    handler.feed = feed

    handler.update_images

    handler.podcast.feed_images.first.original_url.must_equal 'http://prx.org/thumb.png'
    handler.podcast.itunes_images.first.original_url.must_equal 'http://prx.org/image.png'
  end

  it 'update_categories' do
    feed = OpenStruct.new(
      categories: ["Science & Medicine", "Natural Sciences", "Fictional"]
    )
    podcast = Podcast.new
    handler = PodcastFeedHandler.new(podcast)
    handler.feed = feed

    handler.update_categories

    podcast.itunes_categories.size.must_equal 1
    podcast.itunes_categories.first.name.must_equal "Science & Medicine"
    podcast.categories.first.must_equal "Fictional"
  end
end
