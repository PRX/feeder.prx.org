require "test_helper"

class PodcastPlannerControllerTest < ActionDispatch::IntegrationTest
  setup_current_user { build(:user) }
  setup { @podcast = create(:podcast) }

  test "should show podcast_planner" do
    get podcast_planner_url(@podcast)
    assert_response :success
  end

  test "should update podcast_planner" do
    # patch podcast_planner_url(@podcast), params: {podcast_planner: {}}
    # assert_redirected_to podcast_planner_url(@podcast)
  end
end
