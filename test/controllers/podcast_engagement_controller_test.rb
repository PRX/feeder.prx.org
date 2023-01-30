require "test_helper"

class PodcastEngagementsControllerTest < ActionDispatch::IntegrationTest
  setup_current_user { build(:user) }
  setup { @podcast = create(:podcast) }

  test "should show podcast_engagement" do
    get podcast_engagement_url(@podcast)
    assert_response :success
  end

  test "should update podcast_engagement" do
    patch podcast_engagement_url(@podcast), params: {podcast_engagement: {}}
    assert_redirected_to podcast_engagement_url(@podcast)
  end
end
