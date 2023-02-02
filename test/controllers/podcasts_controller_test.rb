require "test_helper"

class PodcastsControllerTest < ActionDispatch::IntegrationTest
  let(:podcast) { create(:podcast, prx_account_uri: "/api/v1/accounts/123") }
  let(:params) { {title: "title", subtitle: "subtitle", prx_account_uri: "/api/v1/accounts/123"} }

  setup_current_user { build(:user, account_id: 123) }

  test "should get index" do
    get podcasts_url
    assert_response :success
  end

  test "should get new" do
    get new_podcast_url
    assert_response :success
  end

  test "should create podcast" do
    assert_difference("Podcast.count") do
      post podcasts_url, params: {podcast: params}
    end

    assert_redirected_to podcast_url(Podcast.last)
  end

  test "authorizes creating podcasts" do
    post podcasts_url, params: {podcast: params.merge(prx_account_uri: "/api/v1/accounts/456")}
    assert_response :forbidden
  end

  test "validates creating podcasts" do
    post podcasts_url, params: {podcast: params.merge(title: "")}
    assert_response :unprocessable_entity
  end

  test "should show podcast" do
    get podcast_url(podcast)
    assert_response :success
  end

  test "authorizes showing podcasts" do
    podcast.update(prx_account_uri: "/api/v1/accounts/456")
    get podcast_url(podcast)
    assert_response :forbidden
  end

  test "should get edit" do
    get edit_podcast_url(podcast)
    assert_response :success
  end

  test "authorizes editing podcasts" do
    podcast.update(prx_account_uri: "/api/v1/accounts/456")

    get edit_podcast_url(podcast)
    assert_response :forbidden
  end

  test "should update podcast" do
    patch podcast_url(podcast), params: {podcast: params}
    assert_redirected_to edit_podcast_url(podcast)
  end

  test "authorizes updating podcasts" do
    podcast.update(prx_account_uri: "/api/v1/accounts/456")
    patch podcast_url(podcast), params: {podcast: params}
    assert_response :forbidden
  end

  test "validates updating podcasts" do
    patch podcast_url(podcast), params: {podcast: params.merge(title: "")}
    assert_response :unprocessable_entity
  end

  test "should destroy podcast" do
    assert podcast

    assert_difference("Podcast.count", -1) do
      delete podcast_url(podcast)
    end

    assert_redirected_to podcasts_url
  end

  test "authorizes destroying podcasts" do
    podcast.update(prx_account_uri: "/api/v1/accounts/456")
    delete podcast_url(podcast)
    assert_response :forbidden
  end

  test "validates destroying podcasts" do
    ep = create(:episode, podcast: podcast)

    # cannot delete with published eps
    delete podcast_url(podcast)
    assert_response :unprocessable_entity

    # can delete once unpublished
    ep.update(published_at: nil)
    delete podcast_url(podcast)
    assert_redirected_to podcasts_url
  end
end
