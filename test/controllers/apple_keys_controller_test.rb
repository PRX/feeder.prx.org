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
      post podcast_apple_keys_url(podcast), params: {apple_key: key_params.merge(account_id: 456)}
    end

    assert_equal 123, Apple::Key.last.account_id
    assert_redirected_to podcast_integrations_url(podcast)
    assert_equal "Apple credential uploaded", flash[:notice]
  end

  test "rejects writes from another account" do
    podcast.update!(prx_account_uri: "/api/v1/accounts/456")

    assert_no_difference "Apple::Key.count" do
      post podcast_apple_keys_url(podcast), params: {apple_key: key_params}
    end

    assert_response :forbidden
  end

  test "renders account credential errors" do
    selected_key = create(:apple_key, account_id: 123)
    podcast.update!(apple_key: selected_key)
    create(:apple_show_feed_binding, feed: podcast.default_feed, apple_show_id: "show-1")

    post podcast_apple_keys_url(podcast), params: {
      apple_key: key_params.merge(provider_id: "short")
    }

    assert_response :unprocessable_entity
    assert_select "body", text: /Provider is too short/
    assert_select "body", text: /Stubbed Account \(123\)/
    assert_select "select[name='podcast[apple_key_id]'] option[selected][value='#{selected_key.id}']", count: 1
    assert_select "select[data-confirm-with]", count: 1
    assert_select "form[action='#{podcast_apple_keys_path(podcast)}'] input[name='apple_key[provider_id]'][value='short']", count: 1
    assert_equal "Unable to upload Apple credential", flash[:error]
  end

  test "removes an unused account credential" do
    key = create(:apple_key, account_id: 123)

    assert_difference "Apple::Key.count", -1 do
      delete podcast_apple_key_url(podcast, key)
    end

    assert_redirected_to podcast_integrations_url(podcast)
    assert_equal "Apple credential removed", flash[:notice]
  end

  test "uses a generic alert when credential removal fails without model errors" do
    key = create(:apple_key, account_id: 123)

    Apple::Key.stub_any_instance(:destroy, false) do
      assert_no_difference "Apple::Key.count" do
        delete podcast_apple_key_url(podcast, key)
      end
    end

    assert_redirected_to podcast_integrations_url(podcast)
    assert_equal "Unable to remove Apple credential", flash[:alert]
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

  test "removes a credential after its podcast is destroyed" do
    key = create(:apple_key, account_id: 123)
    deleted_podcast = create(:podcast, prx_account_uri: "/api/v1/accounts/123", apple_key: key)
    deleted_podcast.destroy!

    assert_difference "Apple::Key.count", -1 do
      delete podcast_apple_key_url(podcast, key)
    end

    assert_redirected_to podcast_integrations_url(podcast)
    assert_equal "Apple credential removed", flash[:notice]
  end

  test "rejects credential uploads by a read only user" do
    ApplicationController.stub_any_instance(:prx_auth_token, build(:read_only_user, account_id: 123)) do
      assert_no_difference "Apple::Key.count" do
        post podcast_apple_keys_url(podcast), params: {apple_key: key_params}
      end

      assert_response :forbidden
    end
  end

  test "rejects credential removal by a read only user" do
    key = create(:apple_key, account_id: 123)

    ApplicationController.stub_any_instance(:prx_auth_token, build(:read_only_user, account_id: 123)) do
      assert_no_difference "Apple::Key.count" do
        delete podcast_apple_key_url(podcast, key)
      end

      assert_response :forbidden
    end
  end
end
