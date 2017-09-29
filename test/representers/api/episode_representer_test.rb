require 'test_helper'

describe Api::EpisodeRepresenter do

  let(:episode) { create(:episode) }
  let(:representer) { Api::EpisodeRepresenter.new(episode) }
  let(:json) { JSON.parse(representer.to_json) }

  it 'includes basic properties' do
    json['prxUri'].must_match /\/api\/v1\/stories\//
    json['summary'].must_match /<a href="\/tina">Tina<\/a>/
  end

  it 'includes clean title, season, episode, and ep type info' do
    json['seasonNumber'].must_be_instance_of(Fixnum)
    json['episodeNumber'].must_be_instance_of(Fixnum)
    json['cleanTitle'].must_match /Clean title/
    json['itunesType'].must_equal 'full'
  end

  it 'uses summary when not blank' do
    episode.summary = 'summary has <a href="/">a link</a>'
    episode.description = '<b>tags</b> removed, <a href="/">links remain</a>'
    json['summary'].must_equal episode.summary
    json['summaryPreview'].must_be_nil
    json['description'].must_equal episode.description
  end

  it 'uses sanitized description for nil summary' do
    episode.summary = nil
    episode.description = '<b>tags</b> removed, <a href="/">links remain</a>'
    json['summary'].must_be_nil
    json['summaryPreview'].must_equal 'tags removed, <a href="/">links remain</a>'
    json['description'].must_equal episode.description
  end

  it 'has links' do
    json['_links']['self']['href'].must_equal "/api/v1/episodes/#{episode.guid}"
    json['_links']['prx:podcast']['href'].must_equal "/api/v1/podcasts/#{episode.podcast.id}"
    json['_links']['prx:story']['href'].must_equal "https://cms.prx.org#{episode.prx_uri}"
  end

  it 'has media' do
    json['media'].size.must_equal 1
    json['media'].first['href'].must_equal episode.enclosure.url
    json['media'].first['original_url'].must_equal episode.enclosure.original_url
  end

  it 'has image' do
    json['images'].size.must_equal 1
    json['images'].first['url'].must_equal episode.image.url
    json['images'].first['original_url'].must_equal episode.image.original_url
  end

  it 'has enclosure' do
    json['_links']['enclosure']['href'].must_equal episode.media_url
  end
end
