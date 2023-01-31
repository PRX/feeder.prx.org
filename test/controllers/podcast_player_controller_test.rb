require "test_helper"

class PodcastPlayerControllerTest < ActionDispatch::IntegrationTest
  setup_current_user { build(:user) }
  setup { @podcast = create(:podcast) }

  test "should show podcast_player" do
    get podcast_player_url(@podcast)
    assert_response :success
  end
end
