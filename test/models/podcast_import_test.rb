require 'test_helper'
require 'prx_access'
require 'ostruct'

describe PodcastImport do
  include PRXAccess

  let(:user) { create(:user) }
  let(:account) { create(:account, id: 8, opener: user) }
  let(:series) { create(:series, account: account) }
  let(:podcast_url) { 'http://feeds.prx.org/transistor_stem' }
  let(:importer) { PodcastImport.create(user: user, account: account, url: podcast_url) }

  before do
    stub_requests
  end

  let(:feed) { Feedjira::Feed.parse(test_file('/fixtures/transistor_two.xml')) }
  let(:series) { create(:series) }
  let(:template) { create(:audio_version_template, series: series) }
  let(:distribution) do
    create(:podcast_distribution,
           distributable: series,
           url: 'https://feeder.prx.org/api/v1/podcasts/51')
  end
  let(:feed_with_video) { Feedjira::Feed.parse(test_file('/fixtures/99pi-feed-rss.xml')) }

  let(:podcast) do
    api_resource(JSON.parse(json_file('transistor_podcast_basic')), feeder_root).tap do |r|
      r.headers = r.headers.merge('Authorization' => 'Bearer thisisnotatoken')
    end
  end

  it 'retrieves a valid feed' do
    importer.get_feed
    importer.feed.wont_be_nil
  end

  it 'retrieves a config' do
    importer.config_url = 'http://test.prx.org/transistor_import_config.json'
    importer.config[:program].must_equal 'transistor_stem'
    importer.config[:audio]['https://transistor.prx.org/?p=1286'].count.must_equal 2
  end

  it 'fails when feed is invalid' do
    importer.url = 'https://www.prx.org/search/all.atom?q=radio'
    -> { importer.get_feed }.must_raise(RuntimeError)
  end

  it 'creates a series' do
    importer.feed = feed
    importer.create_or_update_series!
    importer.series.wont_be_nil
    importer.series.account_id.wont_be_nil
    importer.series.title.must_equal 'Transistor'
    importer.series.short_description.must_equal 'A podcast of scientific questions and ' +
                                                 'stories featuring guest hosts and reporters.'
    importer.series.description.must_equal 'Transistor is a podcast of scientific curiosities ' +
                                           'and current events, featuring guest hosts, ' +
                                           'scientists, and story-driven reporters. Presented ' +
                                           'by radio and podcast powerhouse PRX, with support ' +
                                           'from the Sloan Foundation.'
    importer.series.images.count.must_equal 2
    importer.distribution.wont_be_nil
    importer.distribution.distributable.must_equal importer.series
  end

  it 'creates a podcast' do
    importer.feed = feed
    importer.series = series
    importer.distribution = distribution.tap { |d| d.url = nil }
    importer.create_or_update_podcast!
    importer.podcast.wont_be_nil
    importer.podcast.title.must_equal 'Transistor'
    importer.podcast.serial_order.must_equal false
    importer.podcast.locked.must_equal true
  end

  it 'creates podcast episode imports' do
    importer.config_url = 'http://test.prx.org/transistor_import_config.json'
    importer.feed = feed
    importer.series = series
    series.audio_version_templates.clear
    importer.distribution = distribution
    importer.podcast = podcast
    episode_imports = importer.create_or_update_episode_imports!
    ei = episode_imports.first

    importer.series.audio_version_templates.count.must_equal 2
    importer.distribution.audio_version_templates.count.must_equal 2
  end

  it 'imports a feed' do
    importer.import
  end

  it 'handles audio and video templates in episodes' do
    importer.feed = feed_with_video
    importer.series = series
    series.audio_version_templates.clear
    importer.distribution = distribution
    importer.podcast = podcast

    importer.create_or_update_episode_imports!

    importer.series.audio_version_templates.count.must_equal 2
    importer.distribution.audio_version_templates.count.must_equal 2
    importer.series.audio_version_templates.
      select { |avt| avt.content_type == AudioFile::VIDEO_CONTENT_TYPE }.count.must_equal 1
  end

  describe 'episodes only' do

    before {
      importer.config[:episodes_only] = true
    }

    it 'must have series set' do
      exception = -> { importer.import }.must_raise(RuntimeError)
      exception.message.must_be :start_with?, 'No series'
    end

    it 'must have podcast distribution' do
      series.distributions.delete_all
      importer.series = series
      exception = -> { importer.import }.must_raise(RuntimeError)
      exception.message.must_be :start_with?, 'No podcast distribution'
    end

    it 'imports with a series and podcast' do
      importer.series = series
      importer.import
    end
  end

  describe 'helper methods' do
    let(:sample_link1) do
      'https://www.podtrac.com/pts/redirect.mp3/audio.wnyc.org/' +
        'radiolab_podcast/radiolab_podcast17updatecrispr.mp3'
    end
    let(:sample_link2) do
      'http://www.podtrac.com/pts/redirect.mp3/media.blubrry.com' +
        '/99percentinvisible/dovetail.prxu.org/99pi/9350e921-b910' +
        '-4b1c-bbc6-2912d79d014f/248-Atom-in-the-Garden-of-Eden.mp3'
    end
    let(:sample_link3) do
      'http://media.blubrry.com/some_name/www.podtrac.com/pts/redirect.mp3/blah'
    end

    it 'can make a good guess for an enclosure prefix' do
      item = feed.entries.first
      importer.enclosure_prefix(item).must_equal 'https://dts.podtrac.com/redirect' +
                                                 '.mp3/media.blubrry.com/transistor/'
      item.feedburner_orig_enclosure_link = nil
      item.enclosure.url = sample_link1
      importer.enclosure_prefix(item).must_equal 'https://www.podtrac.com/pts/redirect.mp3/'
      item.feedburner_orig_enclosure_link = 'something_without_those_words'
      item.enclosure.url = sample_link2
      importer.enclosure_prefix(item).must_equal 'http://www.podtrac.com/pts/redirect' +
                                                 '.mp3/media.blubrry.com/99percentinvisible/'
      item.feedburner_orig_enclosure_link = sample_link3
      importer.enclosure_prefix(item).must_equal 'http://www.podtrac.com/pts/redirect.mp3' +
                                                 '/media.blubrry.com/some_name/'
    end

    it 'can substitute for a missing short description' do
      importer.podcast_short_desc(feed).must_equal 'A podcast of scientific questions and stories' +
                                                   ' featuring guest hosts and reporters.'
      feed.itunes_subtitle = nil
      importer.podcast_short_desc(feed).must_equal 'A podcast of scientific questions and stories,' +
                                                   ' with many episodes hosted by key scientists' +
                                                   ' at the forefront of discovery.'
      feed.description = nil
      importer.podcast_short_desc(feed).must_equal 'Transistor'
    end

    it 'can remove feedburner tracking pixels' do
      desc = 'desc <img src="http://feeds.feedburner.com/~r/transistor_stem/~4/NHnLCsjtdQM" ' +
             'height="1" width="1" alt=""/>'
      importer.remove_feedburner_tracker(desc).must_equal 'desc'
    end

    it 'can remove unsafe tags' do
      desc = 'desc <iframe src="/"></iframe><script src="/"></script>'
      importer.sanitize_html(desc).must_equal 'desc'
    end

    it 'can interpret explicit values' do
      %w(Yes TRUE Explicit).each { |x| importer.explicit(x).must_equal 'explicit' }
      %w(NO False Clean).each { |x| importer.explicit(x).must_equal 'clean' }
      %w(UnClean y N 1 0).each { |x| importer.explicit(x).must_equal x.downcase }
    end
  end

  describe('#episode_imports') do

    it('should create episode import placeholders') do
      importer.url = 'http://feeds.prx.org/transistor_stem_duped'
      importer.import
      importer.episode_imports.having_duplicate_guids.count.must_equal 3
      importer.episode_imports.count.must_equal 3
    end

    it('should delete all import placeholders with each import') do
      importer.url = 'http://feeds.prx.org/transistor_stem_duped'
      importer.import_series!
      # invoke the creation of placeholders
      importer.import_episodes!
      importer.create_or_update_episode_imports!
      importer.episode_imports.having_duplicate_guids.count.must_equal 3
    end

  end

  describe('#parse_feed_entries_for_dupe_guids') do
    let(:rss_feed) { Feedjira::Feed.parse(test_file('/fixtures/transistor_dupped_guids.xml')) }

    it 'will parse feed entries for good and duped entries' do
      importer.feed = rss_feed
      good_entries, dupped_guid_entries = importer.parse_feed_entries_for_dupe_guids
      good_entries.length.must_equal 3
      dupped_guid_entries.length.must_equal 3
    end

    it 'handles entry lists of size 0' do
      importer.feed = []
      good_entries, dupped_guid_entries = importer.parse_feed_entries_for_dupe_guids
      good_entries.length.must_equal 0
      dupped_guid_entries.length.must_equal 0
    end

    it 'handles entry lists of size 1' do
      importer.feed = [OpenStruct.new(entry_id: 1)]
      good_entries, dupped_guid_entries = importer.parse_feed_entries_for_dupe_guids
      good_entries.length.must_equal 1
      dupped_guid_entries.length.must_equal 0
    end
  end

  describe('#episode_importing_count') do

    it 'registers the count of episodes that it will be importing' do
      importer.import
      importer.episode_importing_count.must_equal 2
      importer.episode_imports.count.must_equal 2

      importer.series.stories.count.must_equal 0
    end
  end

  describe('#status') do
    it 'sets a status based on the episode imports' do
      importer.import
      importer.status.must_equal PodcastImport::IMPORTING

      ep1 = importer.episode_imports[0]
      ep2 = importer.episode_imports[1]

      importer.status.must_equal PodcastImport::IMPORTING

      ep1.update_attributes! status: EpisodeImport::COMPLETE
      ep2.update_attributes! status: EpisodeImport::COMPLETE

      importer.reload

      importer.complete?.must_equal true
      importer.finished?.must_equal true
      importer.some_failed?.must_equal false
      importer.status.must_equal PodcastImport::COMPLETE
    end

    it 'is failed so long as the import is finished' do
      importer.import
      importer.status.must_equal PodcastImport::IMPORTING

      ep1 = importer.episode_imports[0]
      ep2 = importer.episode_imports[1]

      ep1.update_attributes! status: EpisodeImport::FAILED
      ep2.update_attributes! status: EpisodeImport::COMPLETE

      importer.reload

      importer.complete?.must_equal false
      importer.finished?.must_equal true
      importer.some_failed?.must_equal true
      importer.status.must_equal PodcastImport::FAILED
    end

    it 'is in progress so long as the episode imports are not all created' do
      importer.import

      # simulate a more imports than currently created
      importer.update_attributes(episode_importing_count: 3)
      importer.episode_imports.length.must_equal 2

      ep1 = importer.episode_imports[0]
      ep2 = importer.episode_imports[1]

      ep1.update_attributes! status: EpisodeImport::FAILED
      ep2.update_attributes! status: EpisodeImport::FAILED

      importer.reload

      importer.complete?.must_equal false
      importer.finished?.must_equal false
      importer.some_failed?.must_equal true
      importer.status.must_equal PodcastImport::IMPORTING
    end

    it 'is in progress so long as the episode imports are not finished' do
      importer.import

      # simulate a more imports than currently created
      importer.episode_imports.length.must_equal 2

      ep1 = importer.episode_imports[0]
      ep2 = importer.episode_imports[1]

      ep1.update_attributes! status: EpisodeImport::FAILED
      ep2.update_attributes! status: EpisodeImport::STORY_SAVED

      importer.reload

      importer.complete?.must_equal false
      importer.finished?.must_equal false
      importer.some_failed?.must_equal true
      importer.status.must_equal PodcastImport::IMPORTING
    end
  end
end

def stub_requests
  stub_request(:get, 'http://feeds.prx.org/transistor_stem').
    to_return(status: 200, body: test_file('/fixtures/transistor_two.xml'), headers: {})

  stub_request(:get, 'http://test.prx.org/transistor_import_config.json').
    to_return(status: 200, body: json_file('transistor_import_config'), headers: {})

  stub_request(:get, 'https://www.prx.org/search/all.atom?q=radio').
    to_return(status: 200, body: test_file('/fixtures/prx-atom.xml'), headers: {})

  stub_request(:post, 'https://id.prx.org/token').
    to_return(status: 200,
              body: '{"access_token":"thisisnotatoken","token_type":"bearer"}',
              headers: { 'Content-Type' => 'application/json; charset=utf-8' })

  stub_request(:get, 'https://feeder.prx.org/api/v1').
    with(headers: { 'Authorization' => 'Bearer thisisnotatoken' }).
    to_return(status: 200, body: json_file('feeder_root'), headers: {})

  stub_request(:get, 'https://feeder.prx.org/api/v1/podcasts/51').
    with(headers: { 'Authorization' => 'Bearer thisisnotatoken' }).
    to_return(status: 200, body: json_file('transistor_podcast_basic'), headers: {})

  stub_request(:post, 'https://feeder.prx.org/api/v1/podcasts').
    with(body: /prxUri/).
    to_return(status: 200, body: json_file('transistor_podcast_basic'), headers: {})

  stub_request(:post, 'https://feeder.prx.org/api/v1/podcasts/51/episodes').
    with(body: /prxUri/,
         headers: { 'Authorization' => 'Bearer thisisnotatoken' }).
    to_return(status: 200, body: json_file('transistor_episode'), headers: {})

  stub_request(:get, "https://feeder.prx.org/api/v1/authorization/episodes/153e6ea8-6485-4d53-9c22-bd996d0b3b03").
    with(headers: { 'Authorization'=>'Bearer thisisnotatoken' }).
    to_return(status: 200, body: json_file('transistor_episode'), headers: {})

  stub_request(:get, "https://feeder.prx.org/api/v1/podcasts/23").
    with(headers: { 'Authorization' => 'Bearer thisisnotatoken' }).
    to_return(status: 200, body: json_file('transistor_podcast_basic'), headers: {})

  stub_request(:get, 'http://feeds.prx.org/transistor_stem_duped').
    to_return(status: 200, body: test_file('/fixtures/transistor_dupped_guids.xml'), headers: {})
end
