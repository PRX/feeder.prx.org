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

  test "renders account credential errors" do
    post podcast_apple_keys_url(podcast), params: {
      apple_key: key_params.merge(provider_id: "short")
    }

    assert_response :unprocessable_entity
    assert_select "body", text: /Provider is too short/
    assert_select "body", text: /Stubbed Account \(123\)/
  end

  test "removes an unused account credential" do
    key = create(:apple_key, account_id: 123)

    assert_difference "Apple::Key.count", -1 do
      delete podcast_apple_key_url(podcast, key)
    end

    assert_redirected_to podcast_integrations_url(podcast)
  end

  test "does not remove a credential selected by a podcast" do
    key = create(:apple_key, account_id: 123)
    podcast.update!(apple_key: key)

    assert_no_difference "Apple::Key.count" do
      delete podcast_apple_key_url(podcast, key)
    end

    assert_redirected_to podcast_integrations_url(podcast)
    assert_equal "Apple credentials cannot be removed while podcasts use them", flash[:alert]
  end

  test "does not remove a credential from another account" do
    key = create(:apple_key, account_id: 456)

    assert_no_difference "Apple::Key.count" do
      assert_raises ActiveRecord::RecordNotFound do
        delete podcast_apple_key_url(podcast, key)
      end
    end
  end
end
