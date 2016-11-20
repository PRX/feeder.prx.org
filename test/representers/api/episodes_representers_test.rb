require 'test_helper'

describe Api::EpisodeRepresenter do

  let(:episode) { create(:episode) }
  let(:representer) { Api::EpisodeRepresenter.new(episode) }
  let(:json) { JSON.parse(representer.to_json) }

  it 'includes basic properties' do
    json['prxUri'].must_match /\/api\/v1\/stories\//
  end

  it 'has links' do
    json['_links']['self']['href'].must_equal "/api/v1/episodes/#{episode.guid}"
    json['_links']['prx:podcast']['href'].must_equal "/api/v1/podcasts/#{episode.podcast.id}"
    json['_links']['prx:story']['href'].must_equal "https://cms.prx.org#{episode.prx_uri}"
  end

  it 'has media' do
    json['media'].size.must_equal 1
    json['media'].first['href'].must_equal episode.enclosure.url
  end
end
