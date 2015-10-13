require 'test_helper'

describe EpisodesController do
  let(:episode) { create(:episode) }

  it 'pulls episodes by guid' do
    get :show, id: episode.guid, format: 'json'
    response.body.must_equal EpisodeRepresenter.new(episode).to_json
  end
end
