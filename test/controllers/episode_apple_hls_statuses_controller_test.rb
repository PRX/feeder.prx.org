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

  def stub_filtered(resource, data)
    stub_request(:get, "#{api_base}/shows/show-1/#{resource}?filter%5Bguid%5D=#{episode.item_guid}")
      .to_return(status: 200, body: {data: data, links: {self: "#{api_base}/x"}}.to_json)
  end

  test "authorizes the status before calling Apple" do
    podcast.update_column(:prx_account_uri, "/api/v1/accounts/456")

    get episode_apple_hls_status_path(episode)

    assert_response :forbidden
    assert_not_requested :any, /#{api_base}/
  end

  test "refreshes status from Apple" do
    create(:apple_hls_alternate_asset, episode: episode, apple_show_id: "show-1", feeder_guid: episode.item_guid)
    stub_filtered("episodes", [{"id" => "ep-1", "attributes" => {"guid" => episode.item_guid}}])

    get episode_apple_hls_status_path(episode)

    assert_response :success
    assert_select "turbo-frame#apple-hls-statuses .prx-badge-linked", text: "Linked"
  end

  test "renders the serialized status when Apple fails" do
    create(:apple_hls_alternate_asset, episode: episode, apple_show_id: "show-1", feeder_guid: episode.item_guid)
    stub_request(:get, %r{#{api_base}/shows/show-1/episodes}).to_return(status: 500, body: {errors: []}.to_json)

    get episode_apple_hls_status_path(episode)

    assert_response :success
    assert_select ".prx-badge-staged", text: "Staged"
    assert episode.apple_hls_alternate_assets.first.staged?
  end

  test "skips Apple for an ineligible episode with no row" do
    get episode_apple_hls_status_path(episode)

    assert_response :success
    assert_select ".prx-badge-not_eligible", text: "Not Eligible"
    assert_not_requested :any, /#{api_base}/
  end
end
