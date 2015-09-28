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

  it 'sets the guid on save' do
    episode = build(:episode, guid: nil)
    episode.guid.must_be_nil
    episode.save
    episode.guid.wont_be_nil
  end

  it 'is ready to add to a feed' do
    episode.must_be :include_in_feed?
  end

  it 'retrieves latest copy task' do
    episode.most_recent_copy_task.wont_be_nil
  end

  it 'knows if audio is ready' do
    episode.must_be :audio_ready?
    task = Minitest::Mock.new
    task.expect(:complete?, false)
    episode.stub(:most_recent_copy_task, task) do |variable|
      episode.wont_be :audio_ready?
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
      episode.overrides['title'].must_equal 'We Are Stardust'
    end

    it 'can create from entry' do
      podcast = create(:podcast)
      episode = Episode.create_from_entry!(podcast, entry)
      episode.podcast_id.must_equal podcast.id
      episode.guid.wont_be_nil
      episode.overrides[:guid].wont_be_nil
      episode.guid.wont_equal episode.overrides[:guid]
      episode.overrides['title'].must_equal 'We Are Stardust'
    end
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
