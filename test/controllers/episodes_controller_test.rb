require "test_helper"

class EpisodesControllerTest < ActionDispatch::IntegrationTest
  let(:podcast) { create(:podcast, prx_account_uri: "/api/v1/accounts/123") }
  let(:episode) { create(:episode, podcast: podcast, published_at: nil) }
  let(:params) { {title: "title", segment_count: 1} }

  setup_current_user { build(:user, account_id: 123) }

  test "should get index" do
    get episodes_url
    assert_response :success
  end

  test "should get new" do
    get new_podcast_episode_url(podcast)
    assert_response :success
  end

  test "should create episode" do
    assert_difference("Episode.count") do
      post podcast_episodes_url(podcast), params: {episode: params}
    end

    assert_redirected_to edit_episode_url(Episode.last)
  end

  test "authorizes creating episodes" do
    podcast.update(prx_account_uri: "/api/v1/accounts/456")
    post podcast_episodes_url(podcast), params: {episode: params}
    assert_response :forbidden
  end

  test "validates creating episodes" do
    post podcast_episodes_url(podcast), params: {episode: params.merge(title: "")}
    assert_response :unprocessable_entity
  end

  test "should show episode" do
    get episode_url(episode)
    assert_redirected_to edit_episode_url(episode)
  end

  test "should get edit" do
    get edit_episode_url(episode)
    assert_response :success
  end

  test "authorizes editing podcasts" do
    podcast.update(prx_account_uri: "/api/v1/accounts/456")
    get edit_episode_url(episode)
    assert_response :forbidden
  end

  test "should update episode" do
    Episode.stub_any_instance(:copy_media, true) do
      patch episode_url(episode), params: {episode: params}

      assert_redirected_to edit_episode_url(episode)
    end
  end

  test "authorizes updating episodes" do
    podcast.update(prx_account_uri: "/api/v1/accounts/456")
    patch episode_url(episode), params: {episode: params}
    assert_response :forbidden
  end

  test "validates updating episodes" do
    patch episode_url(episode), params: {episode: params.merge(title: "")}
    assert_response :unprocessable_entity
  end

  test "should destroy episode" do
    assert episode

    assert_difference("Episode.count", -1) do
      delete episode_url(episode)
    end

    assert_redirected_to podcast_episodes_url(podcast)
  end

  test "authorizes destroying episodes" do
    podcast.update(prx_account_uri: "/api/v1/accounts/456")
    delete episode_url(episode)
    assert_response :forbidden
  end

  test "validates destroying episodes" do
    episode.update(published_at: 1.hour.ago)

    # cannot delete published episode
    delete episode_url(episode)
    assert_response :unprocessable_entity

    # can delete once unpublished
    episode.update(published_at: 1.hour.from_now)
    delete episode_url(episode)
    assert_redirected_to podcast_episodes_url(podcast)
  end
end
