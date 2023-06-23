require "test_helper"

class EpisodeSegmenterControllerTest < ActionDispatch::IntegrationTest
  let(:podcast) { create(:podcast, prx_account_uri: "/api/v1/accounts/123") }
  let(:episode) do
    ep = create(:episode, podcast: podcast, published_at: nil)
    create(:uncut, episode: ep, status: "complete")
    ep
  end
  let(:params) {}

  setup_current_user { build(:user, account_id: 123) }

  test "shows the segmenter" do
    get episode_segmenter_path(episode)
    assert_response :success
  end

  test "authorizes showing the segmenter" do
    podcast.update(prx_account_uri: "/api/v1/accounts/456")
    get episode_segmenter_path(episode)
    assert_response :forbidden
  end

  test "updates segmentation" do
    Episode.stub_any_instance(:copy_media, true) do
      patch episode_segmenter_path(episode), params: {uncut: {ad_breaks: "[55.66]"}}
      assert_redirected_to episode_segmenter_path(episode)

      assert_equal [55.66], episode.uncut.ad_breaks
      assert_equal 2, episode.reload.contents.size
    end
  end

  test "authorizes updating segmentation" do
    podcast.update(prx_account_uri: "/api/v1/accounts/456")
    patch episode_segmenter_path(episode), params: {uncut: {ad_breaks: "[55.66]"}}
    assert_response :forbidden
  end

  test "validates updating segmentation" do
    post podcast_episodes_url(podcast), params: {uncut: {ad_breaks: "[foo, bar]"}}
    assert_response :unprocessable_entity
  end
end
