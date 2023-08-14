require "test_helper"

class EpisodeSegmenterControllerTest < ActionDispatch::IntegrationTest
  let(:podcast) { create(:podcast, prx_account_uri: "/api/v1/accounts/123") }
  let(:episode) { create(:episode, podcast: podcast, segment_count: 1, published_at: nil) }
  let(:params) { {ad_breaks: 2} }

  setup_current_user { build(:user, account_id: 123) }

  test "shows episode media" do
    get episode_media_path(episode)
    assert_response :success
  end

  test "authorizes showing episode media" do
    podcast.update(prx_account_uri: "/api/v1/accounts/456")
    get episode_media_path(episode)
    assert_response :forbidden
  end

  test "updates episode media" do
    Episode.stub_any_instance(:copy_media, true) do
      patch episode_media_path(episode), params: {episode: params}
      assert_redirected_to episode_media_path(episode)

      assert_equal 3, episode.reload.segment_count
    end
  end

  test "segments uncut media into contents" do
    uncut = create(:uncut, episode: episode, status: "complete")

    # ad markers to match segment count
    params[:uncut_attributes] = {id: uncut.id, ad_breaks: "[1,[2.3, 4]]"}

    Episode.stub_any_instance(:copy_media, true) do
      patch episode_media_path(episode), params: {episode: params}
      assert_redirected_to episode_media_path(episode)

      assert_equal 3, episode.reload.segment_count
      assert_equal 3, episode.contents.size
      assert_equal [[nil, 1], [1, 2.3], [4, nil]], uncut.reload.segmentation
    end
  end

  test "authorizes updating episode media" do
    podcast.update(prx_account_uri: "/api/v1/accounts/456")
    patch episode_media_path(episode), params: {episode: params}
    assert_response :forbidden
  end

  test "validates updating episode media" do
    patch episode_media_path(episode), params: {episode: {ad_breaks: ""}}
    assert_response :unprocessable_entity
  end
end
