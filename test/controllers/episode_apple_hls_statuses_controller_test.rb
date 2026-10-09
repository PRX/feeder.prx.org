require "test_helper"

class EpisodeAppleHlsStatusesControllerTest < ActionDispatch::IntegrationTest
  let(:api_base) { "https://aardvark.prx.org" }
  let(:podcast) { create(:podcast, prx_account_uri: "/api/v1/accounts/123") }
  let(:feed) { create(:public_feed, podcast: podcast) }
  let(:episode) { create(:episode, podcast: podcast, feeds: [podcast.default_feed, feed]) }
  let(:show_feed_binding) { create(:apple_show_feed_binding, feed: feed, apple_show_id: "show-1") }

  setup_current_user { build(:user, account_id: 123) }

  before do
    podcast.update!(apple_key: create(:apple_key, account_id: podcast.account_id))
    create(:apple_hls_config, show_feed_binding: show_feed_binding)
  end

  def stub_filtered(resource, data, ep = episode)
    stub_request(:get, "#{api_base}/shows/show-1/#{resource}?filter%5Bguid%5D=#{ep.item_guid}")
      .to_return(status: 200, body: {data: data, links: {self: "#{api_base}/x"}}.to_json)
  end

  def stub_by_apple_id(data, ep = episode)
    stub_request(:get, "#{api_base}/episodes/#{ep.item_guid}?include=show").to_return(status: 200, body: {data: data}.to_json)
  end

  def video_episode(**attrs)
    create(:hls_video_episode, podcast: podcast, feeds: [podcast.default_feed, feed], **attrs)
  end

  test "authorizes the status before calling Apple" do
    podcast.update_column(:prx_account_uri, "/api/v1/accounts/456")

    get episode_apple_hls_status_path(episode)

    assert_response :forbidden
    assert_not_requested :any, /#{api_base}/
  end

  test "refreshes status from Apple" do
    create(:apple_hls_alternate_asset, episode: episode, apple_show_id: "show-1", feeder_guid: episode.item_guid)
    stub_filtered("episodes", [{"id" => "ep-1", "attributes" => {"guid" => episode.item_guid, "alternateAssetContentUrl" => "https://dovetail.test/ep1.m3u8"}}])

    get episode_apple_hls_status_path(episode)

    assert_response :success
    assert_select "turbo-frame#apple-hls-statuses .prx-badge-linked", text: "Linked"
  end

  test "skips Apple when the row was checked recently" do
    create(:apple_hls_alternate_asset, episode: episode, apple_show_id: "show-1", feeder_guid: episode.item_guid, last_checked_at: 30.seconds.ago)

    get episode_apple_hls_status_path(episode)

    assert_response :success
    assert_select ".prx-badge-staged", text: "Staged"
    assert_not_requested :any, /#{api_base}/
  end

  test "polls Apple when the row's last check is stale" do
    create(:apple_hls_alternate_asset, episode: episode, apple_show_id: "show-1", feeder_guid: episode.item_guid, last_checked_at: 30.seconds.ago)
    stub_filtered("episodes", [{"id" => "ep-1", "attributes" => {"guid" => episode.item_guid, "alternateAssetContentUrl" => "https://dovetail.test/ep1.m3u8"}}])

    travel_to(EpisodeAppleHlsStatusesController::POLL_INTERVAL.from_now) do
      get episode_apple_hls_status_path(episode)
    end

    assert_response :success
    assert_select ".prx-badge-linked", text: "Linked"
    assert_requested :get, %r{#{api_base}/shows/show-1/episodes}
  end

  test "keeps a linked episode whose RSS GUID is its Apple episode id" do
    create(:apple_hls_alternate_asset, episode: episode, apple_show_id: "show-1", feeder_guid: episode.item_guid,
      status: :linked, apple_episode_id: episode.item_guid)
    stub_filtered("episodes", [])
    stub_by_apple_id({"id" => episode.item_guid, "attributes" => {"guid" => "other-guid", "alternateAssetContentUrl" => "https://dovetail.test/ep1.m3u8"},
                      "relationships" => {"show" => {"data" => {"type" => "shows", "id" => "show-1"}}}})

    get episode_apple_hls_status_path(episode)

    assert_response :success
    assert_select "turbo-frame#apple-hls-statuses .prx-badge-linked", text: "Linked"
    assert episode.apple_hls_alternate_assets.first.linked?
  end

  test "renders the serialized status when Apple fails" do
    create(:apple_hls_alternate_asset, episode: episode, apple_show_id: "show-1", feeder_guid: episode.item_guid)
    stub_request(:get, %r{#{api_base}/shows/show-1/episodes}).to_return(status: 500, body: {errors: []}.to_json)

    get episode_apple_hls_status_path(episode)

    assert_response :success
    assert_select ".prx-badge-staged", text: "Staged"
    assert episode.apple_hls_alternate_assets.first.staged?
  end

  test "has no badge for an audio episode with no row" do
    get episode_apple_hls_status_path(episode)

    assert_response :success
    assert_select "turbo-frame#apple-hls-statuses .badge", count: 0
    assert_not_requested :any, /#{api_base}/
  end

  test "polls Apple for a published eligible video with no row" do
    ep = video_episode
    stub_filtered("episodes", [], ep)
    stub_filtered("stagedAlternateAssets", [], ep)

    get episode_apple_hls_status_path(ep)

    assert_response :success
    assert_select ".prx-badge-pending", text: "Pending"
    assert_requested :get, %r{#{api_base}/shows/show-1/episodes}
    assert_not_requested :get, %r{#{api_base}/episodes/}
  end

  test "skips Apple for a video whose HLS is processing" do
    ep = video_episode(hls_status: "processing")

    get episode_apple_hls_status_path(ep)

    assert_response :success
    assert_select ".prx-badge-processing", text: "Processing"
    assert_not_requested :any, /#{api_base}/
  end

  test "shows a failed HLS transcode" do
    ep = video_episode(hls_status: "error")

    get episode_apple_hls_status_path(ep)

    assert_response :success
    assert_select ".prx-badge-failed", text: "Failed"
    assert_not_requested :any, /#{api_base}/
  end

  test "skips Apple for a video not in the feed's RSS" do
    draft = video_episode(published_at: nil)
    older = video_episode(published_at: 2.days.ago)
    video_episode(published_at: 1.day.ago)
    feed.update!(display_episodes_count: 1)

    [draft, older].each do |ep|
      get episode_apple_hls_status_path(ep)

      assert_response :success
      assert_select ".prx-badge-not_published", text: "Not Published"
    end
    assert_not_requested :any, /#{api_base}/
  end

  test "skips Apple for a row of an episode no longer in the feed's RSS" do
    ep = video_episode
    create(:apple_hls_alternate_asset, episode: ep, apple_show_id: "show-1", feeder_guid: ep.item_guid)
    ep.update!(published_at: nil)

    get episode_apple_hls_status_path(ep)

    assert_response :success
    assert_select ".prx-badge-not_published", text: "Not Published"
    assert_not_requested :any, /#{api_base}/
  end
end
