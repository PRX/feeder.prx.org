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
    episode.item_guid.must_equal "prx:jjgo:guid"
  end

  it 'is ready to add to a feed' do
    episode.must_be :include_in_feed?
  end

  it 'knows if audio is ready' do
    episode.enclosures = [create(:enclosure, episode: episode, status: 'created')]
    episode.enclosures.first.wont_be :complete?
    episode.wont_be :media_ready?
    episode.enclosures.first.complete!
    episode.enclosure.must_be :complete?
    episode.must_be :media_ready?
  end

  it 'returns an audio content_type by default' do
    Episode.new.content_type.must_equal 'audio/mpeg'
  end

  it 'returns the first media content_type' do
    episode.content_type.must_equal 'audio/mpeg'
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

  describe 'rss entry' do
    let (:entry) { api_resource(JSON.parse(json_file(:crier_entry)), crier_root) }
    let (:entry_all) { api_resource(JSON.parse(json_file(:crier_all)), crier_root) }
    let (:entry_no_enclosure) { api_resource(JSON.parse(json_file(:crier_no_enclosure)), crier_root) }

    it 'can update from entry' do
      episode.update_from_entry(entry)
      episode.overrides['title'].must_equal 'Episode 12: What We Know'

      episode.title.must_equal 'Episode 12: What We Know'
    end

    it 'can create from entry' do
      podcast = create(:podcast)
      episode = Episode.create_from_entry!(podcast, entry)
      episode.podcast_id.must_equal podcast.id
      episode.guid.wont_be_nil
      episode.original_guid.wont_be_nil
      episode.published_at.wont_be_nil
      episode.guid.wont_equal episode.overrides[:guid]
      episode.title.must_equal 'Episode 12: What We Know'
      episode.url.must_equal 'http://serialpodcast.org'
    end

    it 'fixes libsyn links' do
      entry.attributes["url"] = "http://traffic.libsyn.com/test/test.mp3"
      entry.attributes["feedburner_orig_link"] = nil

      podcast = create(:podcast)
      episode = Episode.create_from_entry!(podcast, entry)
      episode.url.must_equal episode.media_url
    end

    it 'sets all attributes' do
      podcast = create(:podcast)
      episode = Episode.create_from_entry!(podcast, entry_all)
      episode.id.wont_be_nil
      episode.created_at.wont_be_nil
      episode.updated_at.wont_be_nil
      episode.podcast_id.must_equal podcast.id
      episode.guid.wont_be_nil
      episode.prx_uri.must_be_nil
      episode.deleted_at.must_be_nil
      episode.original_guid.must_equal 'http://99percentinvisible.prx.org/?p=1253'
      episode.published_at.must_equal episode.published
      episode.released_at.must_be_nil
      episode.url.must_equal 'http://99percentinvisible.prx.org/2016/10/18/232-mcmansion-hell/'
      episode.author_name.must_equal 'Roman Mars'
      episode.author_email.must_equal 'roman@99pi.org'
      episode.title.must_equal '232- McMansion Hell'
      episode.subtitle.must_equal 'Few forms of contemporary architecture draw as much criticism as the McMansion, a particular type of oversized house that people love to hate. McMansions usually feature 3,000 or more square feet of space and fail to embody a cohesive style or interact...'
      episode.content.must_equal "<p>Few forms of contemporary architecture draw as much criticism as the McMansion, a particular type of oversized house that people love to hate. McMansions usually feature 3,000 or more square feet of space and fail to embody a cohesive style or interact with their environment. Kate Wagner, architecture critic and creator of <a href=\"http://www.mcmansionhell.com/\">McMansion Hell</a>, is on a mission to illustrate just why these buildings are so terrible.</p>\n<p><a href=\"http://99percentinvisible.org/?p=15841&amp;post_type=episode\">McMansion Hell: The Devil is in the Details</a></p>\n<p><a href=\"https://www.commitchange.com/ma/cambridge/prx-inc/campaigns/radiotopia-fall-campaign-2016\">Support 99pi and Radiotopia today</a>! Be part of the 5000 backer FreshBooks challenge: FreshBooks will donate $40,000 to Radiotopia if we get 5000 total new donations during this drive. <a href=\"https://www.freshbooks.com\">FreshBooks</a> makes intuitive and beautiful cloud accounting software for small businesses.</p>\n"
      episode.summary.must_equal 'Few forms of contemporary architecture draw as much criticism as the McMansion, a particular type of oversized house that people love to hate. McMansions usually feature 3,000 or more square feet of space and fail to embody a cohesive style or interact with their environment. Kate Wagner, architecture critic and creator of McMansion Hell, is on a mission to illustrate just why these buildings are so terrible. McMansion Hell: The Devil is in the Details Support 99pi and Radiotopia today! Be part of the 5000 backer FreshBooks challenge: FreshBooks will donate $40,000 to Radiotopia if we get 5000 total new donations during this drive. FreshBooks makes intuitive and beautiful cloud accounting software for small businesses.'
      episode.published.wont_be_nil
      episode.updated.must_be_nil
      episode.image_url.must_equal 'http://cdn.99percentinvisible.org/wp-content/uploads/powerpress/99-1400.png?entry=1'
      episode.explicit.must_equal 'clean'
      episode.keywords.must_equal ["Roman Mars", "Kate Wagner"]
      episode.description.must_equal 'Few forms of contemporary architecture draw as much criticism as the McMansion, a particular type of oversized house that people love to hate. McMansions usually feature 3,000 or more square feet of space and fail to embody a cohesive style or interact with their environment. Kate Wagner, architecture critic and creator of McMansion Hell, is on a mission to illustrate just why these buildings are so terrible. McMansion Hell: The Devil is in the Details Support 99pi and Radiotopia today! Be part of the 5000 backer FreshBooks challenge: FreshBooks will donate $40,000 to Radiotopia if we get 5000 total new donations during this drive. FreshBooks makes intuitive and beautiful cloud accounting software for small businesses.'
      episode.categories.must_equal ["99 Percent Invisible", "architecture", "criticism", "design", "excess", "housing crisis", "Kate Wagner", "mcmansion"]
      episode.block.must_equal false
      episode.is_closed_captioned.must_equal false
      episode.position.must_be_nil
      episode.feedburner_orig_link.must_be_nil
      episode.feedburner_orig_enclosure_link.must_be_nil
      episode.wont_be :is_perma_link
    end


    it 'creates enclosure from entry' do
      podcast = create(:podcast)
      episode = Episode.create_from_entry!(podcast, entry)
      episode.enclosures.size.must_equal 1
    end

    it 'updates enclosure from entry' do
      podcast = create(:podcast)
      episode = Episode.create_from_entry!(podcast, entry)
      episode.enclosures.first.complete!
      first_enclosure = episode.enclosure

      episode.update_from_entry(entry)
      episode.enclosure.must_equal first_enclosure
      episode.enclosures.size.must_equal 1

      episode.enclosure.update_attribute(:original_url, "https://test.com")
      first_enclosure = episode.enclosure
      episode.update_from_entry(entry)
      episode.enclosures.size.must_equal 2
      replacement_enclosure = episode.enclosures.first

      episode.enclosure.must_equal first_enclosure
      first_enclosure.original_url.must_equal "https://test.com"
      replacement_enclosure.original_url.must_equal "http://dts.podtrac.com/redirect.mp3/files.serialpodcast.org/sites/default/files/podcast/1445350094/serial-s01-e12.mp3"

      replacement_enclosure.complete!
      replacement_enclosure.replace_resources!
      episode.enclosures(true).size.must_equal 1
      episode.enclosure.must_equal replacement_enclosure
    end

    it 'creates contents from entry' do
      podcast = create(:podcast)
      episode = Episode.create_from_entry!(podcast, entry)
      episode.all_contents.size.must_equal 2
    end

    it 'updates contents from entry' do
      podcast = create(:podcast)
      episode = Episode.create_from_entry!(podcast, entry)

      # complete just one of them
      episode.all_contents.first.complete!
      episode.reload
      first_content = episode.all_contents.first
      last_content = episode.all_contents.last
      # puts "\nfirst_content #{first_content.inspect}"
      # puts "\nlast_content #{last_content.inspect}"

      episode.update_from_entry(entry)
      episode.reload
      episode.all_contents.first.must_equal first_content
      episode.all_contents.last.must_equal last_content

      first_content = episode.contents.first
      episode.contents.first.update_attributes(original_url: "https://test.com")
      episode.update_from_entry(entry)
      episode.all_contents.size.must_equal 3
      episode.all_contents.group_by(&:position)[first_content.position].size.must_equal 2
    end

    it 'creates contents with no enclosure' do
      podcast = create(:podcast)
      episode = Episode.create_from_entry!(podcast, entry_no_enclosure)
      episode.all_contents.size.must_equal 2
    end

    it 'uses first content url when there is no enclosure' do
      podcast = create(:podcast)
      episode = Episode.create_from_entry!(podcast, entry_no_enclosure)
      episode.all_contents.first.complete!
      episode.reload
      episode.media_url.must_match /#{episode.contents.first.guid}.mp3$/
    end

    it 'returns nil for media_url when there is no audio' do
      podcast = create(:podcast)
      episode = Episode.create_from_entry!(podcast, entry_no_enclosure)
      episode.contents.clear
      episode.media_url.must_equal nil
    end

    it 'return include in feed and has_media false when no audio' do
      podcast = create(:podcast)
      episode = Episode.create_from_entry!(podcast, entry_no_enclosure)
      episode.contents.clear
      episode.wont_be :has_media?
      episode.wont_be :media_ready?
      episode.must_be :include_in_feed?
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

  describe 'prx story' do
    let(:story) do
      msg = json_file(:prx_story_small)
      body = JSON.parse(msg)
      href = body['_links']['self']['href']
      resource = PRXAccess::PRXHyperResource.new(root: 'https://cms.prx.org/api/vi/')
      link = PRXAccess::PRXHyperResource::Link.new(resource, href: href)
      PRXAccess::PRXHyperResource.new_from(body: body, resource: resource, link: link)
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
