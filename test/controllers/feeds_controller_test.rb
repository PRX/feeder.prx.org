require "test_helper"

class FeedsControllerTest < ActionDispatch::IntegrationTest
  let(:podcast) { create(:podcast, prx_account_uri: "/api/v1/accounts/123") }
  let(:feed) { create(:feed, podcast: podcast, private: false) }
  let(:private_feed) { create(:private_feed, podcast: podcast) }
  let(:update_params) { {url: "/a_public_url", display_episodes_count: 5} }

  setup_current_user { build(:user, account_id: 123) }

  # test "should get new" do
  #   get new_feed_url
  #   assert_response :success
  # end

  # test "should create feed" do
  #   assert_difference("Feed.count") do
  #     post feeds_url, params: {feed: {}}
  #   end

  #   assert_redirected_to feed_url(Feed.last)
  # end

  test "authorize show feed" do
    podcast.update(prx_account_uri: "/api/v1/accounts/456")
    get podcast_feed_url(podcast, feed)
    assert_response :forbidden
  end

  test "should show feed" do
    get podcast_feed_url(podcast, feed)
    assert_response :success

    get podcast_feed_url(podcast, private_feed)
    assert_response :success
  end

  test "authorize update feed" do
    podcast.update(prx_account_uri: "/api/v1/accounts/456")
    patch podcast_feed_url(podcast, feed), params: {feed: update_params}
    assert_response :forbidden
  end

  test "should update feed" do
    patch podcast_feed_url(podcast, feed), params: {feed: update_params}
    assert_redirected_to podcast_feed_url(podcast, feed)
  end

  test "validate update feed" do
    patch podcast_feed_url(podcast, feed), params: {feed: {file_name: ""}}
    assert_response :unprocessable_entity
  end

  # test "should destroy feed" do
  #   assert_difference("Feed.count", -1) do
  #     delete feed_url(@feed)
  #   end

  #   assert_redirected_to feeds_url
  # end
end
