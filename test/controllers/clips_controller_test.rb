require "test_helper"

class ClipsControllerTest < ActionDispatch::IntegrationTest
  let(:podcast) { create(:podcast, prx_account_uri: "/api/v1/accounts/123") }
  let(:stream) { create(:stream_recording, podcast: podcast) }
  let(:clip) { create(:stream_resource, stream_recording: stream) }

  setup_current_user { build(:user, account_id: 123) }

  it "lists clips" do
    get podcast_clips_url(podcast)
    assert_response :success
  end

  it "authorizes listing" do
    podcast.update(prx_account_uri: "/api/v1/accounts/456")
    get podcast_clips_url(podcast)
    assert_response :forbidden
  end

  it "shows clips" do
    get podcast_clip_url(podcast, clip)
    assert_response :success
  end

  it "authorizes showing" do
    podcast.update(prx_account_uri: "/api/v1/accounts/456")
    get podcast_clip_url(podcast, clip)
    assert_response :forbidden
  end
end
