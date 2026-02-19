require "test_helper"

class PodcastClipsControllerTest < ActionDispatch::IntegrationTest
  let(:podcast) { create(:podcast, stream_recording: stream, prx_account_uri: "/api/v1/accounts/123") }
  let(:stream) { build(:stream_recording) }
  let(:clip) { create(:stream_resource, stream_recording: stream) }

  setup_current_user { build(:user, account_id: 123) }

  it "lists clips for a podcast" do
    get podcast_clips_url(podcast)
    assert_response :success
  end

  it "authorizes listing" do
    podcast.update(prx_account_uri: "/api/v1/accounts/456")
    get podcast_clips_url(podcast)
    assert_response :forbidden
  end

  it "shows clips for a podcast" do
    get podcast_clip_url(podcast, clip)
    assert_response :success
  end

  it "authorizes showing" do
    podcast.update(prx_account_uri: "/api/v1/accounts/456")
    get podcast_clip_url(podcast, clip)
    assert_response :forbidden
  end

  it "attaches to existing episodes" do
    ep = create(:episode, podcast: podcast)
    assert_nil ep.uncut

    assert_difference("Episode.count", 0) do
      post attach_podcast_clip_url(podcast, clip), params: {stream_resource: {episode: ep.guid}}
    end

    assert_redirected_to episode_media_url(ep)
    refute_nil ep.reload.uncut
    assert_equal "complete", ep.uncut.status
  end

  it "attaches to new episodes" do
    assert_difference("Episode.count", 1) do
      post attach_podcast_clip_url(podcast, clip), params: {stream_resource: {title: "t"}}
    end

    ep = Episode.last
    assert_redirected_to episode_media_url(ep)
    refute_nil ep.reload.uncut
    assert_equal "complete", ep.uncut.status
  end

  it "validates attaching" do
    assert_difference("Episode.count", 0) do
      post attach_podcast_clip_url(podcast, clip), params: {stream_resource: {title: ""}}
    end

    assert_redirected_to podcast_clip_url(podcast, clip)
    assert_equal "Something went horribly wrong", flash[:alert]
  end

  it "authorizes attaching" do
    podcast.update(prx_account_uri: "/api/v1/accounts/456")
    post attach_podcast_clip_url(podcast, clip), params: {stream_resource: {title: "t"}}
    assert_response :forbidden
  end
end
