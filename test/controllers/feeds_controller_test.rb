require "test_helper"

class FeedsControllerTest < ActionDispatch::IntegrationTest
  let(:podcast) { create(:podcast, prx_account_uri: "/api/v1/accounts/123") }
  let(:feed) { create(:feed, podcast: podcast) }

  setup_current_user { build(:user) }

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

  test "should show feed" do
    get podcast_feed_url(podcast, feed)
    assert_response :success
  end

  test "should update feed" do
    patch podcast_feed_url(podcast, feed), params: {feed: {}}
    assert_redirected_to podcast_feed_url(podcast, feed)
  end

  # test "should destroy feed" do
  #   assert_difference("Feed.count", -1) do
  #     delete feed_url(@feed)
  #   end

  #   assert_redirected_to feeds_url
  # end
end
