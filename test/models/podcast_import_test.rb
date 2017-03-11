require 'test_helper'
require 'prx_access'

describe PodcastImport do
  include PRXAccess

  let(:user) { create(:user) }
  let(:account) { create(:account, id: 8, opener: user) }
  let(:podcast_url) { 'http://feeds.prx.org/transistor_stem' }
  let(:importer) { PodcastImport.create(user: user, account: account, url: podcast_url) }

  before do
    stub_requests
  end

  let(:feed) { Feedjira::Feed.parse(test_file('/fixtures/transistor_two.xml')) }
  let(:series) { create(:series) }
  let(:template) { create(:audio_version_template, series: series) }
  let(:distribution) do
    build(:podcast_distribution,
          audio_version_template: template,
          url: 'https://feeder.prx.org/api/v1/podcasts/51')
  end

  let(:podcast) do
    api_resource(JSON.parse(json_file('transistor_podcast')), feeder_root).tap do |r|
      r.headers = r.headers.merge('Authorization' => 'Bearer thisisnotatoken')
    end
  end

  it 'retrieves a valid feed' do
    importer.get_feed
    importer.feed.wont_be_nil
  end

  it 'fails when feed is invalid' do
    importer.url = 'https://www.prx.org/search/all.atom?q=radio'
    -> { importer.get_feed }.must_raise(RuntimeError)
  end

  it 'creates a series' do
    importer.feed = feed
    importer.create_series_from_podcast
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
    importer.series.audio_version_templates.count.must_equal 1
    template = importer.series.audio_version_templates.first
    template.audio_file_templates.count.must_equal 1
    importer.distribution.wont_be_nil
    importer.distribution.distributable.must_equal importer.series
    importer.distribution.audio_version_template.must_equal template
  end

  it 'creates a podcast' do
    importer.feed = feed
    importer.series = series
    importer.template = template
    importer.distribution = distribution.tap { |d| d.url = nil }
    importer.create_podcast
    importer.podcast.wont_be_nil
    importer.podcast.title.must_equal 'Transistor'
  end

  it 'creates stories' do
    importer.feed = feed
    importer.series = series
    importer.template = template
    importer.distribution = distribution
    importer.podcast = podcast
    stories = importer.create_stories
    f = stories.first
    f.description.must_match /^For the next few episodes/
    f.description.wont_match /<script/
    f.description.wont_match /<iframe/
    f.description.wont_match /feedburner/
    f.account_id.wont_be_nil
    f.creator_id.wont_be_nil
    f.series_id.wont_be_nil
    f.published_at.wont_be_nil
    f.images.count.must_equal 1
    f.audio_versions.count.must_equal 1
    version = f.audio_versions.first
    version.audio_version_template_id.wont_be_nil
    version.label.must_equal 'Podcast Audio'
    version.explicit.must_be_nil
    l = stories.last
    l.images.count.must_equal 0
  end

  it 'imports a feed' do
    importer.import
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
      %w(Yes TRUE Explicit).each { |x| importer.explicit(x).must_equal 'yes' }
      %w(NO False Clean).each { |x| importer.explicit(x).must_equal 'clean' }
      %w(UnClean y N 1 0).each { |x| importer.explicit(x).must_equal x.downcase }
    end
  end
end

def stub_requests
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

  stub_request(:get, 'https://feeder.prx.org/api/v1/podcasts/51').
    with(headers: { 'Authorization' => 'Bearer thisisnotatoken' }).
    to_return(status: 200, body: json_file('transistor_podcast'), headers: {})

  stub_request(:post, 'https://feeder.prx.org/api/v1/podcasts').
    with(body: /prxUri/).
    to_return(status: 200, body: json_file('transistor_podcast'), headers: {})

  stub_request(:post, 'https://feeder.prx.org/api/v1/podcasts/51/episodes').
    with(body: /prxUri/,
         headers: { 'Authorization' => 'Bearer thisisnotatoken' }).
    to_return(status: 200, body: json_file('transistor_episode'), headers: {})
end
