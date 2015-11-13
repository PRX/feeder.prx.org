require 'test_helper'
require 'prx_access'

describe Podcast do

  include PRXAccess

  let(:podcast) { create(:podcast) }

  it 'has episodes' do
    podcast.must_respond_to(:episodes)
  end

  it 'has iTunes categories' do
    podcast.must_respond_to(:itunes_categories)
  end

  it 'updates last build date after update' do
    Timecop.freeze
    podcast.update_attributes(managing_editor: 'Brian Fernandez')

    podcast.last_build_date.must_equal Time.now

    Timecop.return
  end

  describe 'from feed' do
    let (:entry) { api_resource(JSON.parse(json_file(:crier_entry)), crier_root) }

    before {
      stub_request(:get, "http://serialpodcast.org/sites/all/modules/custom/serial/img/serial-itunes-logo.png").
        to_return(:status => 200, :body => test_file('/fixtures/transistor1400.jpg'), :headers => {})
    }

    it 'create_from_feed' do
      feed = entry.objects['prx:feed']
      podcast = Podcast.create_from_feed!(feed)
    end

    it 'update_from_feed' do
      feed = entry.objects['prx:feed']

      podcast = Podcast.new
      podcast.update_from_feed(feed)

      podcast.title.must_equal 'Serial'
      podcast.source_url.must_equal 'https://s3.amazonaws.com/prx-dovetail/testserial/serialpodcast.xml'
      podcast.link.must_equal 'http://serialpodcast.org'
      podcast.author_name.must_equal 'This American Life'
      podcast.owner_name.must_be_nil
      podcast.owner_email.must_equal 'rich@strangebirdlabs.com'
    end

    it 'update_images' do
      podcast = Podcast.new
      attributes = {
        thumb_url: 'http://prx.org/thumb.png',
        image_url: 'http://prx.org/image.png'
      }
      podcast.update_images(attributes)
      podcast.feed_image.url.must_equal 'http://prx.org/thumb.png'
      podcast.itunes_image.url.must_equal 'http://prx.org/image.png'
    end

    it 'update_categories' do
      podcast = Podcast.new
      feed = OpenStruct.new(
        categories: ["Science & Medicine", "Natural Sciences", "Fictional"]
      )

      podcast.update_categories(feed)

      podcast.itunes_categories.size.must_equal 1
      podcast.itunes_categories.first.name.must_equal "Science & Medicine"
      podcast.categories.first.must_equal "Fictional"
    end
  end

  describe 'episode limit' do
    let(:episodes) { create_list(:episode, 10, podcast: podcast).reverse }

    it 'returns only limited number of episodes' do
      episodes.count.must_equal podcast.episodes.count
      podcast.feed_episodes.count.must_equal 10
      podcast.max_episodes = 5
      podcast.feed_episodes.count.must_equal 5
    end
  end
end
