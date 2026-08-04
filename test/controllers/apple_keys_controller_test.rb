require "test_helper"

class AppleKeysControllerTest < ActionDispatch::IntegrationTest
  let(:podcast) { create(:podcast, prx_account_uri: "/api/v1/accounts/123") }
  let(:key_params) do
    {
      provider_id: SecureRandom.uuid,
      key_id: "uploaded_key_id",
      key_pem_b64: Base64.encode64(test_file("/fixtures/apple_podcasts_connect_keyfile.pem"))
    }
  end

  setup_current_user { build(:user, account_id: 123) }

  test "creates an Apple credential in the podcast account" do
    assert_difference "Apple::Key.count", 1 do
      post podcast_apple_keys_url(podcast), params: {apple_key: key_params}
    end

    assert_equal 123, Apple::Key.last.account_id
    assert_redirected_to podcast_integrations_url(podcast)
  end

  test "does not accept a submitted account id" do
    post podcast_apple_keys_url(podcast), params: {apple_key: key_params.merge(account_id: 456)}

    assert_equal 123, Apple::Key.last.account_id
  end

  test "rejects writes from another account" do
    podcast.update!(prx_account_uri: "/api/v1/accounts/456")

    assert_no_difference "Apple::Key.count" do
      post podcast_apple_keys_url(podcast), params: {apple_key: key_params}
    end

    assert_response :forbidden
  end
end
