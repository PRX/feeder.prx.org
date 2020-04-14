require 'test_helper'

describe Api::Auth::EpisodeRepresenter do

  let(:episode) { create(:episode) }
  let(:representer) { Api::Auth::EpisodeRepresenter.new(episode) }
  let(:json) { JSON.parse(representer.to_json) }

  it 'has authorized links' do
    json['_links']['self']['href'].must_equal "/api/v1/authorization/episodes/#{episode.guid}"
  end
end
