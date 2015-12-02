require 'test_helper'
require 'prx_access'

describe Episode do
  include PRXAccess

  let(:episode) { create(:episode) }

  it 'initializes guid and overrides' do
    e = Episode.new
    e.guid.wont_be_nil
    e.overrides.wont_be_nil
  end

  it 'must belong to a podcast' do
    episode = build_stubbed(:episode)
    episode.must_be(:valid?)
    episode.must_respond_to(:podcast)

    episode = build_stubbed(:episode, podcast: nil)
    episode.wont_be(:valid?)
  end

  it 'lazily sets the guid' do
    episode = build(:episode, guid: nil)
    episode.guid.wont_be_nil
  end

  it 'returns a guid ot use in the channel item' do
    episode.guid = 'guid'
    episode.item_guid.must_equal "prx:jjgo:guid"
  end

  it 'is ready to add to a feed' do
    episode.must_be :include_in_feed?
  end

  it 'knows if audio is ready' do
    episode.enclosure = create(:enclosure, episode: episode, status: 'created')
    episode.enclosure.wont_be :complete?
    episode.wont_be :audio_ready?
    episode.enclosure.complete!
    episode.enclosure.must_be :complete?
    episode.must_be :audio_ready?
  end

  describe 'enclosure template' do
    before {
      episode.guid = 'guid'
      episode.podcast.path = 'foo'
    }

    it 'appends podtrac redirect to audio file link' do
      episode.podcast.enclosure_template = 'http://foo.com/r{extension}/b/n/{host}{+path}'

      url = 'http://test-f.prxu.org/podcast/episode/filename.mp3'
      new_url = episode.enclosure_template_url(url)
      new_url.must_equal('http://foo.com/r.mp3/b/n/test-f.prxu.org/podcast/episode/filename.mp3')
    end

    it 'can include the slug from the podcast' do
      episode.podcast.enclosure_template = "{slug}"
      episode.enclosure_template_url("http://example.com/foo.mp3").must_equal("foo")
    end

    it 'can include the guid' do
      episode.podcast.enclosure_template = "{guid}"
      episode.enclosure_template_url("http://example.com/foo.mp3").must_equal("guid")
    end

    it 'can include all properties' do
      episode.podcast.enclosure_template = "http://fake.host/{slug}/{guid}{extension}{?host}"
      url = episode.enclosure_template_url("http://example.com/path/filename.extension")
      url.must_equal("http://fake.host/foo/guid.extension?host=example.com")
    end
  end

  describe 'rss entry' do
    let (:entry) {
      data = json_file(:crier_entry)
      body = data.is_a?(String) ? JSON.parse(data) : data
      api_resource(body, crier_root)
    }

    it 'can update from entry' do
      episode = Episode.new
      episode.update_from_entry(entry)
      episode.overrides['title'].must_equal 'Episode 12: What We Know'
    end

    it 'can create from entry' do
      podcast = create(:podcast)
      episode = Episode.create_from_entry!(podcast, entry)
      episode.podcast_id.must_equal podcast.id
      episode.guid.wont_be_nil
      episode.original_guid.wont_be_nil
      episode.published_at.wont_be_nil
      episode.guid.wont_equal episode.overrides[:guid]
      episode.overrides['title'].must_equal 'Episode 12: What We Know'
    end

    it 'creates enclosure from entry' do
      podcast = create(:podcast)
      episode = Episode.create_from_entry!(podcast, entry)
      episode.enclosure.wont_be_nil
    end

    it 'updates enclosure from entry' do
      podcast = create(:podcast)
      episode = Episode.create_from_entry!(podcast, entry)
      first_enclosure = episode.enclosure

      episode.update_from_entry(entry)
      episode.enclosure.must_equal first_enclosure

      first_enclosure.original_url = "https://test.com"
      episode.update_from_entry(entry)
      episode.enclosure.wont_equal first_enclosure
    end

    it 'creates contents from entry' do
      podcast = create(:podcast)
      episode = Episode.create_from_entry!(podcast, entry)
      episode.contents.size.must_equal 2
    end

    it 'updates contents from entry' do
      podcast = create(:podcast)
      episode = Episode.create_from_entry!(podcast, entry)
      first_content = episode.contents.first
      last_content = episode.contents.last

      episode.update_from_entry(entry)
      episode.contents.first.must_equal first_content
      episode.contents.last.must_equal last_content

      episode.contents.first.original_url = "https://test.com"
      episode.update_from_entry(entry)
      episode.contents(true).first.id.wont_equal first_content.id
      episode.contents.last.must_equal last_content
    end
  end

  it 'proxies podcast_slug to #podcast' do
    podcast = build_stubbed(:podcast)
    episode = build_stubbed(:episode, podcast: podcast)
    podcast.stub(:path, 'podcast path!') do
      episode.podcast_slug.must_equal('podcast path!')
    end
  end

  it 'has no audio file until processed' do
    episode = build_stubbed(:episode)
    episode.audio_files.length.must_equal 0
  end

  it 'has one audio file once processed' do
    episode = create(:episode)
    episode.audio_files.length.must_equal 1
  end

  it 'has a 0 duration when unprocessed' do
    episode = build_stubbed(:episode)
    episode.duration.must_equal 0
  end

  it 'has duration once processed' do
    episode = create(:episode)
    episode.enclosure = create(:enclosure, episode: episode, status: 'complete', duration: 10)
    episode.duration.must_equal 10
  end

  describe 'prx story' do
    let(:story) do
      msg = json_file(:prx_story_small)
      body = JSON.parse(msg)
      href = body['_links']['self']['href']
      resource = HyperResource.new(root: 'https://cms.prx.org/api/vi/')
      link = HyperResource::Link.new(resource, href: href)
      HyperResource.new_from(body: body, resource: resource, link: link)
    end

    it 'can be created from a story' do
      podcast = create(:podcast, prx_uri: '/api/v1/series/32166')
      episode = Episode.create_from_story!(story)
      episode.wont_be_nil
      episode.published_at.wont_be_nil
    end

    it 'can be found by story' do
      create(:episode, prx_uri: '/api/v1/stories/80548')
      episode = Episode.by_prx_story(story)
      episode.wont_be_nil
    end
  end
end
