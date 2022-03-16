require 'test_helper'

describe Api::Auth::FeedRepresenter do
  let(:podcast) { create(:podcast) }
  let(:feed) { create(:feed, podcast: podcast) }
  let(:representer) { Api::Auth::FeedRepresenter.new(feed) }
  let(:json) { JSON.parse(representer.to_json) }

  it 'includes basic properties' do
    _(json['slug']).must_match /myfeed(\d+)/
  end

  it 'has links' do
    _(json['_links']['self']['href']).must_equal "/api/v1/authorization/podcasts/#{feed.podcast.id}/feeds/#{feed.id}"
    _(json['_links']['prx:podcast']['href']).must_equal "/api/v1/authorization/podcasts/#{feed.podcast.id}"
  end

  it 'has a feed rss link' do
    _(json['_links']['prx:private-feed']['href']).must_equal feed.published_url
    _(json['_links']['prx:private-feed']['templated']).must_equal true
    _(json['_links']['prx:private-feed']['type']).must_equal 'application/rss+xml'
  end
end
