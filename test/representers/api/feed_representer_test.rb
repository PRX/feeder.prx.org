require 'test_helper'

describe Api::FeedRepresenter do
  let(:feed) { create(:feed, overrides: {title: '88% Parentheticals'}) }
  let(:representer) { Api::FeedRepresenter.new(feed) }
  let(:json) { JSON.parse(representer.to_json) }

  it 'includes basic properties' do
    json['name'].must_match /test-/
    json['overrides']['title'].must_equal '88% Parentheticals'
  end

  it 'has links' do
    json['_links']['self']['href'].must_equal "/api/v1/podcasts/#{feed.podcast.id}/feeds/#{feed.id}"
    json['_links']['prx:podcast']['href'].must_equal "/api/v1/podcasts/#{feed.podcast.id}"
  end
end
