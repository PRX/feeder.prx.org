require "test_helper"

class PodcastPlannerControllerTest < ActionDispatch::IntegrationTest
  setup_current_user { build(:user, account_id: 123) }
  setup { @podcast = create(:podcast, prx_account_uri: "/api/v1/accounts/123") }

  test "should show podcast_planner" do
    get podcast_planner_url(@podcast)
    assert_response :success
  end

  # test "should update podcast_planner" do
  #   patch podcast_planner_url(@podcast), params: {podcast_planner: {}}
  #   assert_redirected_to podcast_planner_url(@podcast)
  # end
end
