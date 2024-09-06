require "test_helper"

class EpisodeTranscriptsControllerTest < ActionDispatch::IntegrationTest
  let(:podcast) { create(:podcast, prx_account_uri: "/api/v1/accounts/123") }
  let(:episode) { create(:episode, podcast: podcast, published_at: nil) }
  let(:params) { {transcript_attributes: {original_url: "test/fixtures/differenttranscript.txt"}} }

  setup_current_user { build(:user, account_id: 123) }

  test "shows episode transcript" do
    get episode_transcripts_path(episode)
    assert_response :success
  end

  test "authorizes showing episode transcript" do
    podcast.update(prx_account_uri: "/api/v1/accounts/456")
    get episode_transcripts_path(episode)
    assert_response :forbidden
  end

  test "updates episode transcript" do
    Episode.stub_any_instance(:copy_media, true) do
      patch episode_transcripts_path(episode), params: {episode: params}
      assert_redirected_to episode_transcripts_path(episode)
    end
  end

  test "authorizes updating episode transcript" do
    podcast.update(prx_account_uri: "/api/v1/accounts/456")
    patch episode_transcripts_path(episode), params: {episode: params}
    assert_response :forbidden
  end
end
