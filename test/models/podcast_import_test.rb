require 'test_helper'
require 'prx_access'

describe PodcastImport do
  include PRXAccess

  let(:account) { create(:account, id: 8) }
  let(:podcast_url) { 'http://feeds.prx.org/transistor_stem' }
  let(:importer) { PodcastImport.create(account: account, url: podcast_url) }

  before do
    stub_requests
  end

  let(:feed) { Feedjira::Feed.parse(test_file('/fixtures/transistor.xml')) }
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
  end

  it 'creates a series' do
    importer.feed = feed
    importer.series = series
    importer.template = template
    importer.distribution = distribution.tap { |d| d.url = nil }
    importer.create_podcast
    importer.podcast.wont_be_nil
  end

  it 'creates stories' do
    importer.feed = feed
    importer.series = series
    importer.template = template
    importer.distribution = distribution
    importer.podcast = podcast
    importer.create_stories
  end

  it 'imports a feed' do
    importer.import
  end

end

def stub_requests
  stub_request(:get, 'http://feeds.prx.org/transistor_stem').
    to_return(status: 200, body: test_file('/fixtures/transistor.xml'), headers: {})

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
