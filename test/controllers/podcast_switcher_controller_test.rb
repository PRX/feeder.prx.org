require "test_helper"

class PodcastPlayerControllerTest < ActionDispatch::IntegrationTest
  setup_current_user { build(:user, account_id: 123, scopes: "feeder:read-private") }

  let(:p1) { create(:podcast, title: "This podcast abcd", prx_account_uri: "/api/v1/accounts/123") }
  let(:p2) { create(:podcast, title: "Other podcast efgh", prx_account_uri: "/api/v1/accounts/123") }
  let(:p3) { create(:podcast, title: "Third podcast abcd", prx_account_uri: "/api/v1/accounts/456") }

  test "should show your authorized podcasts" do
    assert [p1, p2, p3]

    get podcast_switcher_url
    assert_response :success

    assert_match p1.title, @response.body
    assert_match p2.title, @response.body
    refute_match p3.title, @response.body
  end

  test "should search your authorized podcasts" do
    assert [p1, p2, p3]

    post podcast_switcher_url, params: {q: "abcd"}, as: :turbo_stream
    assert_response :success

    assert_match p1.title, @response.body
    refute_match p2.title, @response.body
    refute_match p3.title, @response.body
  end
end
