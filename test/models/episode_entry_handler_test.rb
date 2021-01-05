require 'test_helper'
require 'prx_access'

describe EpisodeEntryHandler do
  include PRXAccess

  let(:episode) { create(:episode) }
  let(:entry) { api_resource(JSON.parse(json_file(:crier_entry)), crier_root) }
  let(:entry_all) { api_resource(JSON.parse(json_file(:crier_all)), crier_root) }
  let(:entry_no_enclosure) { api_resource(JSON.parse(json_file(:crier_no_enclosure)), crier_root) }

  before {
    stub_request(:get, 'http://cdn.99percentinvisible.org/wp-content/uploads/powerpress/99-1400.png?entry=1').
      to_return(status: 200, body: test_file('/fixtures/transistor1400.jpg'), headers: {})
  }

  it 'can update from entry' do
    EpisodeEntryHandler.update_from_entry!(episode, entry)
    assert_equal episode.title, 'Episode 12: What We Know'
  end

  it 'can create from entry' do
    podcast = create(:podcast)
    episode = EpisodeEntryHandler.create_from_entry!(podcast, entry)
    assert_equal episode.podcast_id, podcast.id
    refute_nil episode.guid
    refute_nil episode.original_guid
    refute_nil episode.published_at
    refute_equal episode.guid, episode.overrides[:guid]
    assert_equal episode.title, 'Episode 12: What We Know'
    assert_equal episode.url, 'http://serialpodcast.org'
  end

  it 'fixes libsyn links' do
    entry.attributes["url"] = "http://traffic.libsyn.com/test/test.mp3"
    entry.attributes["feedburner_orig_link"] = nil

    podcast = create(:podcast)
    episode = EpisodeEntryHandler.create_from_entry!(podcast, entry)
    assert_nil episode.url
  end

  it 'sets all attributes' do
    podcast = create(:podcast)
    episode = EpisodeEntryHandler.create_from_entry!(podcast, entry_all)
    refute_nil episode.id
    refute_nil episode.created_at
    refute_nil episode.updated_at
    assert_equal episode.podcast_id, podcast.id
    refute_nil episode.guid
    assert_nil episode.prx_uri
    assert_nil episode.deleted_at
    assert_equal episode.original_guid, 'http://99percentinvisible.prx.org/?p=1253'
    assert_equal episode.published_at, episode.published_at
    assert_equal episode.url, 'http://99percentinvisible.prx.org/2016/10/18/232-mcmansion-hell/'
    assert_equal episode.author_name, 'Roman Mars'
    assert_equal episode.author_email, 'roman@99pi.org'
    assert_equal episode.title, '232- McMansion Hell'
    assert_equal episode.subtitle, 'Few forms of contemporary architecture draw as much criticism as the McMansion, a particular type of oversized house that people love to hate. McMansions usually feature 3,000 or more square feet of space and fail to embody a cohesive style or interact...'
    assert_equal episode.content, "<p>Few forms of contemporary architecture draw as much criticism as the McMansion, a particular type of oversized house that people love to hate. McMansions usually feature 3,000 or more square feet of space and fail to embody a cohesive style or interact with their environment. Kate Wagner, architecture critic and creator of <a href=\"http://www.mcmansionhell.com/\">McMansion Hell</a>, is on a mission to illustrate just why these buildings are so terrible.</p>\n<p><a href=\"http://99percentinvisible.org/?p=15841&amp;post_type=episode\">McMansion Hell: The Devil is in the Details</a></p>\n<p><a href=\"https://www.commitchange.com/ma/cambridge/prx-inc/campaigns/radiotopia-fall-campaign-2016\">Support 99pi and Radiotopia today</a>! Be part of the 5000 backer FreshBooks challenge: FreshBooks will donate $40,000 to Radiotopia if we get 5000 total new donations during this drive. <a href=\"https://www.freshbooks.com\">FreshBooks</a> makes intuitive and beautiful cloud accounting software for small businesses.</p>\n"
    assert_equal episode.summary, 'Few forms of contemporary architecture draw as much criticism as the McMansion, a particular type of oversized house that people love to hate. McMansions usually feature 3,000 or more square feet of space and fail to embody a cohesive style or interact with their environment. Kate Wagner, architecture critic and creator of McMansion Hell, is on a mission to illustrate just why these buildings are so terrible. McMansion Hell: The Devil is in the Details Support 99pi and Radiotopia today! Be part of the 5000 backer FreshBooks challenge: FreshBooks will donate $40,000 to Radiotopia if we get 5000 total new donations during this drive. FreshBooks makes intuitive and beautiful cloud accounting software for small businesses.'
    assert_equal episode.explicit, 'clean'
    assert_equal episode.keywords, ["roman mars", "kate wagner"]
    assert_equal episode.description, 'Few forms of contemporary architecture draw as much criticism as the McMansion, a particular type of oversized house that people love to hate. McMansions usually feature 3,000 or more square feet of space and fail to embody a cohesive style or interact with their environment. Kate Wagner, architecture critic and creator of McMansion Hell, is on a mission to illustrate just why these buildings are so terrible. McMansion Hell: The Devil is in the Details Support 99pi and Radiotopia today! Be part of the 5000 backer FreshBooks challenge: FreshBooks will donate $40,000 to Radiotopia if we get 5000 total new donations during this drive. FreshBooks makes intuitive and beautiful cloud accounting software for small businesses.'
    assert_equal episode.categories, ["99 Percent Invisible", "architecture", "criticism", "design", "excess", "housing crisis", "Kate Wagner", "mcmansion"]
    assert_equal episode.block, false
    assert_equal episode.is_closed_captioned, false
    assert_nil episode.position
    assert_nil episode.feedburner_orig_link
    assert_nil episode.feedburner_orig_enclosure_link
    refute episode.is_perma_link
  end

  it 'creates image for entry' do
    podcast = create(:podcast)
    episode = EpisodeEntryHandler.create_from_entry!(podcast, entry_all)
    assert_equal episode.images.first.original_url, 'http://cdn.99percentinvisible.org/wp-content/uploads/powerpress/99-1400.png?entry=1'
  end

  it 'creates enclosure from entry' do
    podcast = create(:podcast)
    episode = EpisodeEntryHandler.create_from_entry!(podcast, entry)
    assert_equal episode.enclosures.size, 1
  end

  it 'updates enclosure from entry' do
    podcast = create(:podcast)
    episode = EpisodeEntryHandler.create_from_entry!(podcast, entry)
    episode.enclosures.first.complete!
    first_enclosure = episode.enclosure

    EpisodeEntryHandler.update_from_entry!(episode, entry)
    assert_equal episode.enclosure, first_enclosure
    assert_equal episode.enclosures.size, 1

    episode.enclosure.update_attribute(:original_url, "https://test.com")
    first_enclosure = episode.enclosure
    EpisodeEntryHandler.update_from_entry!(episode, entry)
    assert_equal episode.enclosures.size, 2
    replacement_enclosure = episode.enclosures.first

    assert_equal episode.enclosure, first_enclosure
    assert_equal first_enclosure.original_url, "https://test.com"
    assert_equal replacement_enclosure.original_url, "http://dts.podtrac.com/redirect.mp3/files.serialpodcast.org/sites/default/files/podcast/1445350094/serial-s01-e12.mp3"

    replacement_enclosure.complete!
    replacement_enclosure.replace_resources!
    assert_equal episode.enclosures(true).size, 1
    assert_equal episode.enclosure, replacement_enclosure
  end

  it 'will not changes enclosure when file name same' do
    podcast = create(:podcast)
    episode = EpisodeEntryHandler.create_from_entry!(podcast, entry)
    episode.enclosures.first.complete!
    first_enclosure = episode.enclosure

    assert_equal first_enclosure.original_url, "http://dts.podtrac.com/redirect.mp3/files.serialpodcast.org/sites/default/files/podcast/1445350094/serial-s01-e12.mp3"
    first_enclosure.update_attribute(:original_url, "http://www.podtrac.com/redirect.mp3/files.serialpodcast.org/sites/default/files/podcast/1445350094/serial-s01-e12.mp3")
    EpisodeEntryHandler.update_from_entry!(episode, entry)
    assert_equal episode.enclosures(true).size, 1
    assert_equal episode.enclosures.first.original_url, "http://www.podtrac.com/redirect.mp3/files.serialpodcast.org/sites/default/files/podcast/1445350094/serial-s01-e12.mp3"
  end

  it 'updates enclosure when only file name changes' do
    podcast = create(:podcast)
    episode = EpisodeEntryHandler.create_from_entry!(podcast, entry)
    episode.enclosures.first.complete!
    first_enclosure = episode.enclosure

    assert_equal first_enclosure.original_url, "http://dts.podtrac.com/redirect.mp3/files.serialpodcast.org/sites/default/files/podcast/1445350094/serial-s01-e12.mp3"
    first_enclosure.update_attribute(:original_url, "http://dts.podtrac.com/redirect.mp3/files.serialpodcast.org/sites/default/files/podcast/1445350094/serial-s01-e12_original.mp3")
    EpisodeEntryHandler.update_from_entry!(episode, entry)
    assert_equal episode.enclosures(true).size, 2
    assert_equal episode.enclosures.first.original_url, "http://dts.podtrac.com/redirect.mp3/files.serialpodcast.org/sites/default/files/podcast/1445350094/serial-s01-e12.mp3"
    assert_equal episode.enclosures.last.original_url, "http://dts.podtrac.com/redirect.mp3/files.serialpodcast.org/sites/default/files/podcast/1445350094/serial-s01-e12_original.mp3"
  end

  it 'creates contents from entry' do
    podcast = create(:podcast)
    episode = EpisodeEntryHandler.create_from_entry!(podcast, entry)
    assert_equal episode.all_contents.size, 2
  end

  it 'updates contents from entry' do
    podcast = create(:podcast)
    episode = EpisodeEntryHandler.create_from_entry!(podcast, entry)

    # complete just one of them
    episode.all_contents.first.complete!
    episode.reload
    first_content = episode.all_contents.first
    last_content = episode.all_contents.last

    EpisodeEntryHandler.update_from_entry!(episode, entry)
    episode.reload
    assert_equal episode.all_contents.first, first_content
    assert_equal episode.all_contents.last, last_content

    first_content = episode.contents.first
    assert_equal first_content.original_url, 'https://s3.amazonaws.com/prx-dovetail/testserial/serial_audio.mp3'
    first_content.update_attributes(original_url: 'https://prx-dovetail.amazonaws.com/testserial/serial_audio.mp3')
    EpisodeEntryHandler.update_from_entry!(episode, entry)
    assert_equal episode.all_contents(true).size, 2

    first_content.update_attributes(original_url: 'https://s3.amazonaws.com/prx-dovetail/testserial/serial_audio_original.mp3')
    EpisodeEntryHandler.update_from_entry!(episode, entry)
    assert_equal episode.all_contents(true).size, 3
    assert_equal episode.all_contents.group_by(&:position)[first_content.position].size, 2
  end

  it 'creates contents with no enclosure' do
    podcast = create(:podcast)
    episode = EpisodeEntryHandler.create_from_entry!(podcast, entry_no_enclosure)
    assert_equal episode.all_contents.size, 2
  end

  it 'uses first content url when there is no enclosure' do
    podcast = create(:podcast)
    episode = EpisodeEntryHandler.create_from_entry!(podcast, entry_no_enclosure)
    episode.all_contents.first.complete!
    episode.reload
    assert_match(/#{episode.contents.first.guid}.mp3$/, episode.media_url)
  end

  it 'returns nil for media_url when there is no audio' do
    podcast = create(:podcast)
    episode = EpisodeEntryHandler.create_from_entry!(podcast, entry_no_enclosure)
    episode.all_contents.clear
    assert_nil episode.media_url
  end

  it 'return include in feed and has_media false when no audio' do
    podcast = create(:podcast)
    episode = EpisodeEntryHandler.create_from_entry!(podcast, entry_no_enclosure)
    episode.all_contents.clear
    refute episode.media?
    refute episode.media_ready?
    assert episode.include_in_feed?
  end
end
