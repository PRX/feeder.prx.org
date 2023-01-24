require "test_helper"

describe Api::Auth::EpisodeRepresenter do
  let(:episode) { create(:episode) }
  let(:representer) { Api::Auth::EpisodeRepresenter.new(episode) }
  let(:json) { JSON.parse(representer.to_json) }

  it "has authorized links" do
    assert_equal json["_links"]["self"]["href"], "/api/v1/authorization/episodes/#{episode.guid}"
  end
end
