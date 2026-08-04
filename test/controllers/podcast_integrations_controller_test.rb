require "test_helper"

class PodcastIntegrationsControllerTest < ActionDispatch::IntegrationTest
  let(:podcast) { create(:podcast, prx_account_uri: "/api/v1/accounts/123") }

  setup_current_user { build(:user, account_id: 123) }

  test "shows only Apple credentials from the podcast account" do
    visible = create(:apple_key, account_id: 123, key_id: "visible_key")
    hidden = create(:apple_key, account_id: 456, key_id: "hidden_key_")

    get podcast_integrations_url(podcast)

    assert_response :success
    assert_select "body", text: /#{visible.key_id.last(4)}/
    assert_select "body", text: /#{hidden.key_id.last(4)}/, count: 0
  end

  test "rejects access from another account" do
    podcast.update!(prx_account_uri: "/api/v1/accounts/456")

    get podcast_integrations_url(podcast)

    assert_response :forbidden
  end
end
