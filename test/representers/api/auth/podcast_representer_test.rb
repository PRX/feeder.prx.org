require 'test_helper'

describe Api::Auth::PodcastRepresenter do

  let(:podcast) { create(:podcast) }
  let(:representer) { Api::Auth::PodcastRepresenter.new(podcast) }
  let(:json) { JSON.parse(representer.to_json) }

  it 'has authorized links' do
    assert_equal json['_links']['self']['href'], "/api/v1/authorization/podcasts/#{podcast.id}"
    assert_match("/api/v1/authorization/podcasts/#{podcast.id}/episodes", json['_links']['prx:episodes']['href'])
  end
end
