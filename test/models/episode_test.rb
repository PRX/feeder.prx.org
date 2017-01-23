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

  it 'returns a guid to use in the channel item' do
    episode.guid = 'guid'
    episode.item_guid.must_equal "prx_#{episode.podcast_id}_guid"
  end

  it 'is ready to add to a feed' do
    episode.must_be :include_in_feed?
  end

  it 'knows if audio is ready' do
    episode.enclosures = [create(:enclosure, episode: episode, status: 'created')]
    episode.enclosures.first.wont_be :complete?
    episode.must_be :media?
    episode.wont_be :media_ready?
    episode.media_status.must_equal 'processing'
    episode.enclosures.first.complete!
    episode.enclosure.must_be :complete?
    episode.must_be :media?
    episode.must_be :media_ready?
    episode.media_status.must_equal 'complete'
  end

  it 'returns an audio content_type by default' do
    Episode.new.content_type.must_equal 'audio/mpeg'
  end

  it 'returns the first media content_type' do
    episode.content_type.must_equal 'audio/mpeg'
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
    episode.media_files.length.must_equal 0
  end

  it 'has one audio file once processed' do
    episode = create(:episode)
    episode.media_files.length.must_equal 1
  end

  it 'has a 0 duration when unprocessed' do
    episode = build_stubbed(:episode)
    episode.duration.must_equal 0
  end

  it 'has duration once processed' do
    episode = create(:episode)
    episode.enclosures = [create(:enclosure, episode: episode, status: 'complete', duration: 10)]
    episode.duration.must_equal 10
  end

  it 'has duration with podcast duration padding' do
    episode = create(:episode)
    episode.enclosures = [create(:enclosure, episode: episode, status: 'complete', duration: 10)]
    episode.podcast.duration_padding = 10
    episode.duration.must_equal 20
  end

  it 'updates the podcast published date' do
    now = 1.minute.ago
    podcast = episode.podcast
    orig = episode.podcast.published_at
    now.wont_equal orig
    episode.run_callbacks :save do
      episode.update_attribute(:published_at, now)
    end
    podcast.reload.published_at.to_i.must_equal now.to_i
  end

  describe 'enclosure template' do
    before {
      episode.guid = 'guid'
      episode.podcast.path = 'foo'
    }

    it 'applies template to enclosure url' do
      template = "https://#{ENV['DOVETAIL_HOST']}/{slug}/{guid}/{original_filename}"
      base_url = 'http://test-f.prxu.org/podcast/episode/filename.mp3'
      original_url = 'http://foo.com/whatever/filename.mp3'

      episode.podcast.enclosure_template = template
      episode.podcast.enclosure_prefix = nil
      new_url = episode.enclosure_url(base_url, original_url)
      new_url.must_equal("https://#{ENV['DOVETAIL_HOST']}/foo/guid/filename.mp3")
    end

    it 'applies prefix to enclosure url' do
      pre = 'https://www.podtrac.com/pts/redirect.mp3/media.blubrry.com/test'
      base_url = 'http://test-f.prxu.org/podcast/episode/filename.mp3'
      original_url = 'http://foo.com/whatever/filename.mp3'

      episode.podcast.enclosure_template = nil
      episode.podcast.enclosure_prefix = pre
      new_url = episode.enclosure_url(base_url, original_url)
      new_url.must_equal "#{pre}/test-f.prxu.org/podcast/episode/filename.mp3"
    end

    it 'applies prefix and template' do
      template = "https://#{ENV['DOVETAIL_HOST']}/{slug}/{guid}/{original_filename}"
      pre = 'https://www.podtrac.com/pts/redirect.mp3/media.blubrry.com/test'
      base_url = 'http://test-f.prxu.org/podcast/episode/filename.mp3'
      original_url = 'http://foo.com/whatever/filename.mp3'

      episode.podcast.enclosure_template = template
      episode.podcast.enclosure_prefix = pre
      new_url = episode.enclosure_url(base_url, original_url)
      new_url.must_equal "#{pre}/#{ENV['DOVETAIL_HOST']}/foo/guid/filename.mp3"
    end

    it 'applies template to audio file link' do
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

    it 'gets expansions for original and base urls' do
      base_url = "http://example.com/path/filename.extension"
      original_url = "http://original.com/folder/original.mp3"
      expansions = episode.enclosure_template_expansions(base_url, original_url)
      expansions[:filename].must_equal "filename.extension"
      expansions[:host].must_equal "example.com"
      expansions[:original_filename].must_equal "original.mp3"
      expansions[:original_host].must_equal "original.com"
    end

    it 'can use original properties' do
      episode.podcast.enclosure_template = "http://fake.host/{original_host}/{original_filename}"
      url = episode.enclosure_template_url("http://blah", "http://original.host/path/filename.mp3")
      url.must_equal("http://fake.host/original.host/filename.mp3")
    end
  end

  describe 'prx story' do
    let(:story) do
      msg = json_file(:prx_story_small)
      body = JSON.parse(msg)
      href = body['_links']['self']['href']
      resource = PRXAccess::PRXHyperResource.new(root: 'https://cms.prx.org/api/vi/')
      link = PRXAccess::PRXHyperResource::Link.new(resource, href: href)
      PRXAccess::PRXHyperResource.new_from(body: body, resource: resource, link: link)
    end

    it 'can be found by story' do
      create(:episode, prx_uri: '/api/v1/stories/80548')
      episode = Episode.by_prx_story(story)
      episode.wont_be_nil
    end
  end
end
