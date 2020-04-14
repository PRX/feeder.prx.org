require 'test_helper'

describe Api::Auth::PodcastRepresenter do

  let(:podcast) { create(:podcast) }
  let(:representer) { Api::Auth::PodcastRepresenter.new(podcast) }
  let(:json) { JSON.parse(representer.to_json) }

  it 'has authorized links' do
    json['_links']['self']['href'].must_equal "/api/v1/authorization/podcasts/#{podcast.id}"
    json['_links']['prx:episodes']['href'].must_match "/api/v1/authorization/podcasts/#{podcast.id}/episodes"
  end
end
