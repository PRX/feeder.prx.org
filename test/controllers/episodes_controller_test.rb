require "test_helper"

class EpisodesControllerTest < ActionDispatch::IntegrationTest
  let(:podcast) { create(:podcast, prx_account_uri: "/api/v1/accounts/123") }
  let(:episode) { create(:episode, podcast: podcast, published_at: nil, segment_count: 1) }
  let(:params) { {title: "title", description: "description"} }

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

  test "optimistically locks updating episodes" do
    patch episode_url(episode), params: {episode: {lock_version: episode.lock_version - 1}}
    assert_response :conflict
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

  test "authorizes you aren't destroying published episodes" do
    episode.update(published_at: 1.hour.ago)

    # cannot delete published episode
    delete episode_url(episode)
    assert_response :forbidden

    # can delete once unpublished
    episode.update(published_at: 1.hour.from_now)
    delete episode_url(episode)
    assert_redirected_to podcast_episodes_url(podcast)
  end

  # Error Handling Tests

  test "shows apple integration error state when asset processing fails" do
    _apple_feed = create(:apple_feed, podcast: podcast)
    error_episode = create(:episode, podcast: podcast, published_at: 1.hour.ago, segment_count: 1)

    # Create delivery status showing uploaded but not delivered (processing state)
    create(:apple_episode_delivery_status, episode: error_episode, uploaded: true, delivered: false)

    # Create apple episode with error state
    api_response = build(:apple_episode_api_response,
      item_guid: error_episode.item_guid,
      apple_hosted_audio_state: Apple::Episode::AUDIO_ASSET_FAILURE)
    create(:apple_episode, feeder_episode: error_episode, api_response: api_response)

    get edit_episode_url(error_episode)
    assert_response :success
    assert_select ".prx-badge-error", text: /Error/
  end

  test "shows error badge when delivery file has validation errors" do
    _apple_feed = create(:apple_feed, podcast: podcast)
    error_episode = create(:episode, podcast: podcast, published_at: 1.hour.ago, segment_count: 1)

    # Create delivery status
    create(:apple_episode_delivery_status, episode: error_episode, uploaded: true, delivered: false)

    # Create apple episode without audio asset state (still indeterminate since file failed validation)
    api_response = build(:apple_episode_api_response,
      item_guid: error_episode.item_guid)
    _apple_episode = create(:apple_episode, feeder_episode: error_episode, api_response: api_response)

    # Create podcast container, delivery, and delivery file with validation error
    container = create(:apple_podcast_container, episode: error_episode)
    delivery = create(:apple_podcast_delivery, episode: error_episode, podcast_container: container)
    pdf = create(:apple_podcast_delivery_file, episode: error_episode, podcast_delivery: delivery)

    # Update the sync log with validation error
    pdf.apple_sync_log.update!(**build(:podcast_delivery_file_api_response, asset_processing_state: "VALIDATION_FAILED"))
    error_episode.apple_episode.podcast_delivery_files.reset

    get edit_episode_url(error_episode)
    assert_response :success
    assert_select ".prx-badge-error", text: /Error/
  end
end
