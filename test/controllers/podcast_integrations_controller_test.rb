require "test_helper"

class PodcastIntegrationsControllerTest < ActionDispatch::IntegrationTest
  let(:podcast) { create(:podcast, prx_account_uri: "/api/v1/accounts/123") }

  let(:key_params) do
    {
      provider_id: SecureRandom.uuid,
      key_id: "uploaded_key_id",
      key_pem_b64: Base64.encode64(test_file("/fixtures/apple_podcasts_connect_keyfile.pem"))
    }
  end

  setup_current_user { build(:user, account_id: 123) }

  test "shows only Apple credentials from the podcast account" do
    visible = create(:apple_key, account_id: 123, key_id: "visible_key")
    hidden = create(:apple_key, account_id: 456, key_id: "hidden_key_")
    another_podcast = create(:podcast, prx_account_uri: "/api/v1/accounts/123", apple_key: visible)
    podcast.update!(apple_key: visible)

    get podcast_integrations_url(podcast)

    assert_response :success
    assert_select "body", text: /#{visible.key_id.last(4)}/
    assert_select "body", text: /#{hidden.key_id.last(4)}/, count: 0
    assert_select "select[name='podcast[apple_key_id]'] option[selected][value='#{visible.id}']", count: 1
    assert_select "body", text: /Used by 2 podcasts/
    assert_select "body", text: /Stubbed Account \(123\)/
    assert another_podcast
  end

  test "selects an account credential for the podcast" do
    key = create(:apple_key, account_id: 123)

    patch podcast_integrations_url(podcast), params: {podcast: {apple_key_id: key.id}}

    assert_redirected_to podcast_integrations_url(podcast)
    assert_equal key, podcast.reload.apple_key
  end

  test "does not select a credential from another account" do
    key = create(:apple_key, account_id: 456)

    patch podcast_integrations_url(podcast), params: {podcast: {apple_key_id: key.id}}

    assert_response :unprocessable_entity
    assert_nil podcast.reload.apple_key
    assert_select "body", text: /is not available to this PRX account/
  end

  test "removes a credential when the podcast has no connected Apple shows" do
    key = create(:apple_key, account_id: 123)
    podcast.update!(apple_key: key)

    patch podcast_integrations_url(podcast), params: {podcast: {apple_key_id: ""}}

    assert_redirected_to podcast_integrations_url(podcast)
    assert_nil podcast.reload.apple_key
  end

  test "does not remove a credential while Apple shows are connected" do
    key = create(:apple_key, account_id: 123)
    podcast.update!(apple_key: key)
    create(:apple_show_feed_binding, feed: podcast.default_feed, apple_show_id: "show-1")

    patch podcast_integrations_url(podcast), params: {podcast: {apple_key_id: ""}}

    assert_response :unprocessable_entity
    assert_equal key, podcast.reload.apple_key
  end

  test "changes credentials when the new credential can access connected shows" do
    old_key = create(:apple_key, account_id: 123, key_id: "old_key_id12")
    new_key = create(:apple_key, account_id: 123, key_id: "new_key_id34")
    podcast.update!(apple_key: old_key)
    create(:apple_show_feed_binding, feed: podcast.default_feed, apple_show_id: "show-1")
    body = {data: [{id: "show-1", attributes: {title: "A show"}}], links: {}}.to_json
    stub_request(:get, "https://aardvark.prx.org/shows").to_return(status: 200, body: body)

    patch podcast_integrations_url(podcast), params: {podcast: {apple_key_id: new_key.id}}

    assert_redirected_to podcast_integrations_url(podcast)
    assert_equal new_key, podcast.reload.apple_key
  end

  test "does not change credentials when connected shows are unavailable" do
    old_key = create(:apple_key, account_id: 123, key_id: "old_key_id12")
    new_key = create(:apple_key, account_id: 123, key_id: "new_key_id34")
    podcast.update!(apple_key: old_key)
    create(:apple_show_feed_binding, feed: podcast.default_feed, apple_show_id: "show-1")
    body = {data: [{id: "another-show", attributes: {title: "Another show"}}], links: {}}.to_json
    stub_request(:get, "https://aardvark.prx.org/shows").to_return(status: 200, body: body)

    patch podcast_integrations_url(podcast), params: {podcast: {apple_key_id: new_key.id}}

    assert_response :unprocessable_entity
    assert_equal old_key, podcast.reload.apple_key
    assert_select "body", text: /cannot access the connected Apple shows: show-1/
  end

  test "rejects access from another account" do
    podcast.update!(prx_account_uri: "/api/v1/accounts/456")

    get podcast_integrations_url(podcast)

    assert_response :forbidden
  end

  test "rejects updates from another account" do
    key = create(:apple_key, account_id: 123)
    podcast.update!(prx_account_uri: "/api/v1/accounts/456")

    patch podcast_integrations_url(podcast), params: {podcast: {apple_key_id: key.id}}

    assert_response :forbidden
  end

  test "creates an Apple credential in the podcast account" do
    assert_difference "Apple::Key.count", 1 do
      post podcast_apple_keys_url(podcast), params: {apple_key: key_params}
    end

    assert_equal 123, Apple::Key.last.account_id
    assert_redirected_to podcast_integrations_url(podcast)
    assert_equal "Apple credential uploaded", flash[:notice]
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

  test "does not remove a credential selected by a soft deleted podcast" do
    key = create(:apple_key, account_id: 123)
    deleted_podcast = create(:podcast, prx_account_uri: "/api/v1/accounts/123", apple_key: key)
    deleted_podcast.destroy!

    assert_no_difference "Apple::Key.count" do
      delete podcast_apple_key_url(podcast, key)
    end

    assert_redirected_to podcast_integrations_url(podcast)
    assert_equal "Apple credentials cannot be removed while podcasts use them", flash[:alert]

    get podcast_integrations_url(podcast)

    assert_response :success
    assert_select "form[action='#{podcast_apple_key_path(podcast, key)}']", count: 0
    assert_select "body", text: /Used by a deleted podcast/
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
