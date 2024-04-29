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
    Podcast.stub_any_instance(:copy_media, true) do
      assert_difference("Podcast.count") do
        post podcasts_url, params: {podcast: params}
      end

      assert_redirected_to podcast_url(Podcast.last)
    end
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
    Podcast.stub_any_instance(:copy_media, true) do
      patch podcast_url(podcast), params: {podcast: params}
      assert_redirected_to edit_podcast_url(podcast)
    end
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

  test "authorizes you're not destroying podcasts with published episodes" do
    podcast.update(created_at: 1.year.ago)
    ep = create(:episode, podcast: podcast)

    # cannot delete with published eps
    delete podcast_url(podcast)
    assert_response :forbidden

    # can delete once unpublished
    ep.update(published_at: nil)
    delete podcast_url(podcast)
    assert_redirected_to podcasts_url
  end
end
