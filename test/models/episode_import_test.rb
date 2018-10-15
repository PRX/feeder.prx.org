require 'test_helper'
require 'prx_access'

describe EpisodeImport do
  include PRXAccess

  let(:user) { create(:user) }
  let(:account) { create(:account, id: 8, opener: user) }
  let(:series) { create(:series) }
  let(:template) { create(:audio_version_template, series: series) }
  let(:distribution) do
    create(:podcast_distribution,
           distributable: series,
           url: 'https://feeder.prx.org/api/v1/podcasts/51')
  end

  let(:importer) { create(:podcast_import, user: user, account: account, series: series) }

  let(:feed) { Feedjira::Feed.parse(test_file('/fixtures/transistor_two.xml')) }
  let(:entry) { feed.entries.first }
  let(:entry_libsyn) { feed.entries.last }

  let(:episode_import) do
    EpisodeImport.create!(
      podcast_import: importer,
      entry: entry.to_h,
      guid: 'https://transistor.prx.org/?p=1286'
    )
  end

  let(:libsyn_episode_import) do
    EpisodeImport.create!(
      podcast_import: importer,
      entry: entry.to_h,
      guid: 'https://transistor.prx.org/?p=1287'
    )
  end

  let(:podcast) do
    api_resource(JSON.parse(json_file('transistor_podcast_basic')), feeder_root).tap do |r|
      r.headers = r.headers.merge('Authorization' => 'Bearer thisisnotatoken')
    end
  end

  before do
    stub_episode_requests
  end

  it 'creates a story on import' do
    f = episode_import.import
    f.description.must_match /^For the next few episodes/
    f.description.wont_match /<script/
    f.description.wont_match /<iframe/
    f.description.wont_match /feedburner/
    f.tags.must_include 'Indie Features'
    f.tags.each do |tag|
      tag.wont_match /\n/
      tag.wont_be :blank?
    end
    f.tags.wont_include '\t'
    f.clean_title.must_equal 'Sidedoor iTunes title'
    f.season_identifier.must_equal '2'
    f.episode_identifier.must_equal '4'
    f.distributions.first.get_episode.itunes_type.must_equal 'full'
    f.account_id.wont_be_nil
    f.creator_id.wont_be_nil
    f.series_id.wont_be_nil
    f.published_at.wont_be_nil
    f.images.count.must_equal 1
    f.audio_versions.count.must_equal 1
    config_audio = 'https://dts.podtrac.com/redirect.mp3/media.blubrry.com/transistor/cdn-transistor.prx.org/wp-content/uploads/Smithsonian3_Transistor.mp3'
    f.audio_versions.first.audio_files.first.upload.must_equal config_audio
    version = f.audio_versions.first
    version.audio_version_template_id.wont_be_nil
    version.audio_version_template.segment_count.wont_be_nil
    version.label.must_equal 'Podcast Audio'
    version.explicit.must_be_nil
  end

  it 'creates correctly for libsyn entries' do
    s = libsyn_episode_import.import
    s.distributions.count.must_equal 1
  end

  it 'creates audio entries' do
    ei = EpisodeImport.create!(
      podcast_import: importer,
      entry: entry.to_h,
      guid: 'https://transistor.prx.org/?p=1286'
    )

    ei.audio['files'].present?.must_equal(false)

    ei.import

    ei.audio['files'].present?.must_equal(true)
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

    it 'can substitute for a missing short description' do
      e = entry.to_h.with_indifferent_access
      episode_import.episode_short_desc(e).must_equal 'An astronomer has turned the night sky into a symphony.'

      e[:itunes_subtitle] = ''
      episode_import.episode_short_desc(e).wont_equal ''

      e[:itunes_subtitle] = nil
      episode_import.episode_short_desc(e).must_equal 'Sidedoor from the Smithsonian: Shake it Up'

      e[:description] = 'Some text that\'s under 50 words'
      episode_import.episode_short_desc(e).must_equal 'Some text that\'s under 50 words'
    end

    it 'can substitute for a missing description' do
      entry.description = nil
      entry.itunes_summary = nil
      entry.content = nil
      episode_import.entry_description(entry.to_h.with_indifferent_access).wont_be :blank?
    end

    it 'can remove feedburner tracking pixels' do
      desc = 'desc <img src="http://feeds.feedburner.com/~r/transistor_stem/~4/NHnLCsjtdQM" ' +
             'height="1" width="1" alt=""/>'
      episode_import.remove_feedburner_tracker(desc).must_equal 'desc'
    end

    it 'can remove unsafe tags' do
      desc = 'desc <iframe src="/"></iframe><script src="/"></script>'
      episode_import.sanitize_html(desc).must_equal 'desc'
    end

    it 'can interpret explicit values' do
      %w(Yes TRUE Explicit).each { |x| episode_import.explicit(x).must_equal 'explicit' }
      %w(NO False Clean).each { |x| episode_import.explicit(x).must_equal 'clean' }
      %w(UnClean y N 1 0).each { |x| episode_import.explicit(x).must_equal x.downcase }
    end
  end
end

def stub_episode_requests
  stub_request(:get, 'http://feeds.prx.org/transistor_stem').
    to_return(status: 200, body: test_file('/fixtures/transistor_two.xml'), headers: {})

  stub_request(:get, 'https://www.prx.org/search/all.atom?q=radio').
    to_return(status: 200, body: test_file('/fixtures/prx-atom.xml'), headers: {})

  stub_request(:post, 'https://id.prx.org/token').
    to_return(status: 200,
              body: '{"access_token":"thisisnotatoken","token_type":"bearer"}',
              headers: { 'Content-Type' => 'application/json; charset=utf-8' })

  stub_request(:get, 'https://feeder.prx.org/api/v1').
    with(headers: { 'Authorization' => 'Bearer thisisnotatoken' }).
    to_return(status: 200, body: json_file('feeder_root'), headers: {})

  stub_request(:get, /https:\/\/feeder.prx.org\/api\/v1\/podcasts\/\d+/).
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
end
