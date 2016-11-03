require 'test_helper'
require 'prx_access'

describe EpisodeEntryHandler do
  include PRXAccess

  let(:episode) { create(:episode) }
  let(:entry) { api_resource(JSON.parse(json_file(:crier_entry)), crier_root) }
  let(:entry_all) { api_resource(JSON.parse(json_file(:crier_all)), crier_root) }
  let(:entry_no_enclosure) { api_resource(JSON.parse(json_file(:crier_no_enclosure)), crier_root) }

  it 'can update from entry' do
    EpisodeEntryHandler.update_from_entry!(episode, entry)
    episode.title.must_equal 'Episode 12: What We Know'
  end

  it 'can create from entry' do
    podcast = create(:podcast)
    episode = EpisodeEntryHandler.create_from_entry!(podcast, entry)
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
    episode = EpisodeEntryHandler.create_from_entry!(podcast, entry)
    episode.url.must_equal episode.media_url
  end

  it 'sets all attributes' do
    podcast = create(:podcast)
    episode = EpisodeEntryHandler.create_from_entry!(podcast, entry_all)
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
    episode = EpisodeEntryHandler.create_from_entry!(podcast, entry)
    episode.enclosures.size.must_equal 1
  end

  it 'updates enclosure from entry' do
    podcast = create(:podcast)
    episode = EpisodeEntryHandler.create_from_entry!(podcast, entry)
    episode.enclosures.first.complete!
    first_enclosure = episode.enclosure

    EpisodeEntryHandler.update_from_entry!(episode, entry)
    episode.enclosure.must_equal first_enclosure
    episode.enclosures.size.must_equal 1

    episode.enclosure.update_attribute(:original_url, "https://test.com")
    first_enclosure = episode.enclosure
    EpisodeEntryHandler.update_from_entry!(episode, entry)
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
    episode = EpisodeEntryHandler.create_from_entry!(podcast, entry)
    episode.all_contents.size.must_equal 2
  end

  it 'updates contents from entry' do
    podcast = create(:podcast)
    episode = EpisodeEntryHandler.create_from_entry!(podcast, entry)

    # complete just one of them
    episode.all_contents.first.complete!
    episode.reload
    first_content = episode.all_contents.first
    last_content = episode.all_contents.last
    # puts "\nfirst_content #{first_content.inspect}"
    # puts "\nlast_content #{last_content.inspect}"

    EpisodeEntryHandler.update_from_entry!(episode, entry)
    episode.reload
    episode.all_contents.first.must_equal first_content
    episode.all_contents.last.must_equal last_content

    first_content = episode.contents.first
    episode.contents.first.update_attributes(original_url: "https://test.com")
    EpisodeEntryHandler.update_from_entry!(episode, entry)
    episode.all_contents.size.must_equal 3
    episode.all_contents.group_by(&:position)[first_content.position].size.must_equal 2
  end

  it 'creates contents with no enclosure' do
    podcast = create(:podcast)
    episode = EpisodeEntryHandler.create_from_entry!(podcast, entry_no_enclosure)
    episode.all_contents.size.must_equal 2
  end

  it 'uses first content url when there is no enclosure' do
    podcast = create(:podcast)
    episode = EpisodeEntryHandler.create_from_entry!(podcast, entry_no_enclosure)
    episode.all_contents.first.complete!
    episode.reload
    episode.media_url.must_match /#{episode.contents.first.guid}.mp3$/
  end

  it 'returns nil for media_url when there is no audio' do
    podcast = create(:podcast)
    episode = EpisodeEntryHandler.create_from_entry!(podcast, entry_no_enclosure)
    episode.contents.clear
    episode.media_url.must_equal nil
  end

  it 'return include in feed and has_media false when no audio' do
    podcast = create(:podcast)
    episode = EpisodeEntryHandler.create_from_entry!(podcast, entry_no_enclosure)
    episode.contents.clear
    episode.wont_be :media?
    episode.wont_be :media_ready?
    episode.must_be :include_in_feed?
  end
end
