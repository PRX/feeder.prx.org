require 'test_helper'
require 'prx_access'

describe Episode do
  include PRXAccess

  let(:episode) { create(:episode) }

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
      episode.overrides[:guid].wont_be_nil
      episode.guid.wont_equal episode.overrides[:guid]
      episode.overrides['title'].must_equal 'Episode 12: What We Know'
    end

    it 'creates enclosure from entry' do
      podcast = create(:podcast)
      episode = Episode.create_from_entry!(podcast, entry)
      episode.enclosure.wont_be_nil
    end

    it 'creates contents from entry' do
      podcast = create(:podcast)
      episode = Episode.create_from_entry!(podcast, entry)
      episode.contents.size.must_equal 2
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
    end

    it 'can be found by story' do
      create(:episode, prx_uri: '/api/v1/stories/80548')
      episode = Episode.by_prx_story(story)
      episode.wont_be_nil
    end
  end
end
