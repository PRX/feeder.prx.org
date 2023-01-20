require "test_helper"

describe Authorization do
  let(:account_id) { "123" }
  let(:token) { StubToken.new(account_id, ["feeder:read-private"], 456) }
  let(:authorization) { Authorization.new(token) }
  let(:podcast1) { create(:podcast, prx_account_uri: "/api/v1/accounts/#{account_id}", path: "pod1") }
  let(:podcast2) { create(:podcast, prx_account_uri: "/api/v1/accounts/987", path: "pod2") }
  let(:podcast3) { create(:podcast, prx_account_uri: "/api/v1/accounts/654", path: "pod3") }
  let(:episode1) { create(:episode, podcast: podcast1) }
  let(:episode2) { create(:episode, podcast: podcast2) }
  let(:episode3) { create(:episode, podcast: podcast3) }

  it "has a user_id" do
    assert_equal authorization.user_id, 456
  end

  it "has a token" do
    refute_nil authorization.token
  end

  it "has a cache_key" do
    refute_nil authorization.cache_key
    assert_match(/PRX::Authorization/, authorization.cache_key)
  end

  it "has token accounts" do
    assert_equal authorization.token_auth_account_ids, ["123"]
    assert_equal authorization.token_auth_account_uris, ["/api/v1/accounts/123"]
  end

  it "gets podcasts for token accounts" do
    podcast1 && podcast2 && podcast3
    assert_equal authorization.token_auth_podcasts.count, 1
    assert_equal authorization.token_auth_podcasts.first, podcast1
  end

  it "gets episodes for token accounts" do
    episode1 && episode2 && episode3
    assert_equal authorization.token_auth_episodes.count, 1
    assert_equal authorization.token_auth_episodes.first, episode1
  end
end
