require "test_helper"

describe Api::AuthorizationRepresenter do
  let(:account_id) { "123" }
  let(:token) { StubToken.new(account_id, ["feeder:read-private"], 456) }
  let(:authorization) { Authorization.new(token) }
  let(:representer) { Api::AuthorizationRepresenter.new(authorization) }
  let(:podcast) { create(:podcast, prx_account_uri: "/api/v1/accounts/#{account_id}") }
  let(:episode) { create(:episode, podcast: podcast) }
  let(:json) { JSON.parse(representer.to_json) }

  it "has link to episodes" do
    refute_nil episode.id
    refute_nil json["_links"]["prx:episodes"]
    assert_equal json["_links"]["prx:episodes"]["count"], 1
  end

  it "has link to episode" do
    refute_nil json["_links"]["prx:episode"]
  end

  it "has link to podcasts" do
    refute_nil podcast.id
    refute_nil json["_links"]["prx:podcasts"]
    assert_equal json["_links"]["prx:podcasts"]["count"], 1
  end

  it "has link to podcast" do
    refute_nil json["_links"]["prx:podcast"]
  end
end
