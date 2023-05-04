require "test_helper"

class PodcastEngagementsControllerTest < ActionDispatch::IntegrationTest
  let(:podcast) { create(:podcast, prx_account_uri: "/api/v1/accounts/123") }
  let(:valid_params) { {podcast: {donation_url: "http://prx.org", payment_pointer: "$prx.wallet.example/abcd1234"}} }

  setup_current_user { build(:user, account_id: 123) }

  test "should show podcast_engagement" do
    get podcast_engagement_url(podcast)
    assert_response :success
  end

  test "authorizes editing engagement settings" do
    podcast.update(prx_account_uri: "/api/v1/accounts/456")

    get podcast_engagement_url(podcast)
    assert_response :forbidden
  end

  test "should update podcast_engagement" do
    patch(podcast_engagement_url(podcast), params: valid_params)
    assert_redirected_to podcast_engagement_url(podcast)
  end

  test "authorizes showing podcast engagement settings" do
    podcast.update(prx_account_uri: "/api/v1/accounts/456")
    patch(podcast_engagement_url(podcast), params: valid_params)

    assert_response :forbidden
  end

  test "validates updates to podcast engagement settings" do
    patch podcast_engagement_url(podcast), params: {podcast: {donation_url: "it's almost ryan's lunchtime"}}
    assert_response :unprocessable_entity
  end

  test "allows a blank donation_url" do
    patch podcast_engagement_url(podcast), params: {podcast: {donation_url: ""}}
    assert_redirected_to podcast_engagement_url(podcast)
  end

  test "validates updates to payment pointer" do
    patch podcast_engagement_url(podcast), params: {podcast: {payment_pointer: "it's almost ryan's lunchtime"}}
    assert_response :unprocessable_entity
  end

  test "allows a blank payment pointer" do
    patch podcast_engagement_url(podcast), params: {podcast: {payment_pointer: ""}}
    assert_redirected_to podcast_engagement_url(podcast)
  end
end
