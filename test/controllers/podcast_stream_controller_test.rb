require "test_helper"

class PodcastStreamControllerTest < ActionDispatch::IntegrationTest
  let(:podcast) { create(:podcast, prx_account_uri: "/api/v1/accounts/123") }
  let(:params) { {url: "https://some.where/stream.aac"} }

  setup_current_user { build(:user, account_id: 123) }

  it "shows the podcast stream recording" do
    get podcast_stream_url(podcast)
    assert_response :success
  end

  it "authorizes showing" do
    podcast.update(prx_account_uri: "/api/v1/accounts/456")
    get podcast_stream_url(podcast)
    assert_response :forbidden
  end

  it "creates and updates" do
    assert_difference("StreamRecording.count", 1) do
      put podcast_stream_url(podcast), params: {stream_recording: params}
    end
    assert_redirected_to podcast_stream_url(podcast)

    assert_difference("StreamRecording.count", 0) do
      put podcast_stream_url(podcast), params: {stream_recording: params}
    end
    assert_redirected_to podcast_stream_url(podcast)
  end

  it "validates updates" do
    put podcast_stream_url(podcast), params: {stream_recording: params.merge(url: "")}
    assert_response :unprocessable_entity
  end

  it "authorizes updates" do
    podcast.update(prx_account_uri: "/api/v1/accounts/456")
    put podcast_stream_url(podcast), params: {stream_recording: params}
    assert_response :forbidden
  end
end
