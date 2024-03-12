require "test_helper"

class PodcastPlayerControllerTest < ActionDispatch::IntegrationTest
  let(:podcast) { create(:podcast, prx_account_uri: "/api/v1/accounts/123") }

  setup_current_user { build(:user, account_id: 123) }

  test "should show podcast_player" do
    get podcast_player_url(podcast)
    assert_response :success
  end
end
