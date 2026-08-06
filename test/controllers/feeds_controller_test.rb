require "test_helper"

class FeedsControllerTest < ActionDispatch::IntegrationTest
  let(:podcast) { create(:podcast, prx_account_uri: "/api/v1/accounts/123") }
  let(:feed) { create(:feed, podcast: podcast, private: false) }
  let(:locked_feed) { create(:feed, podcast: podcast, private: false, edit_locked: true) }
  let(:private_feed) { create(:private_feed, podcast: podcast) }
  let(:update_params) { {url: "https://prx.org/a_public_url", display_episodes_count: 5} }
  let(:create_params) { {podcast: podcast, slug: "new_feed", label: "new label", private: false} }

  setup_current_user { build(:user, account_id: 123) }

  test "should get new" do
    get new_podcast_feed_url(podcast)
    assert_response :success
  end

  test "authorize new feed" do
    podcast.update(prx_account_uri: "/api/v1/accounts/456")
    get new_podcast_feed_url(podcast)
    assert_response :forbidden
  end

  test "should create feed" do
    # instantiate first feed to get accurate feed count
    assert podcast
    assert_difference("Feed.count") do
      post podcast_feeds_url(podcast), params: {feed: create_params}
    end

    assert_redirected_to podcast_feed_url(podcast, Feed.last)
  end

  test "creates a legacy Apple key in the podcast account" do
    key_params = {
      provider_id: SecureRandom.uuid,
      key_id: "uploaded_key_id",
      key_pem_b64: Base64.encode64(test_file("/fixtures/apple_podcasts_connect_keyfile.pem"))
    }

    assert_difference "Apple::Key.count", 1 do
      post podcast_feeds_url(podcast), params: {
        feed: {
          type: "Feeds::AppleSubscription",
          private: true,
          delegated_delivery_config_attributes: {key_attributes: key_params}
        }
      }
    end

    assert_redirected_to podcast_feed_url(podcast, Feed.last)
    assert_equal podcast.account_id, Feed.last.delegated_delivery_config.key.account_id
  end

  test "renders and updates delegated delivery settings" do
    apple_feed = create(:apple_feed, podcast: podcast)
    config = apple_feed.delegated_delivery_config

    Feeds::AppleSubscription.stub_any_instance(:apple_show_options, []) do
      get podcast_feed_url(podcast, apple_feed)
    end

    assert_response :success
    assert_select 'input[type="checkbox"][name="feed[delegated_delivery_config_attributes][publish_enabled]"]'

    patch podcast_feed_url(podcast, apple_feed), params: {
      feed: {
        delegated_delivery_config_attributes: {id: config.id, publish_enabled: "0", sync_blocks_rss: "0"}
      }
    }

    assert_redirected_to podcast_feed_url(podcast, apple_feed)
    refute config.reload.publish_enabled
    refute config.sync_blocks_rss
  end

  test "authorizes creating feeds" do
    podcast.update(prx_account_uri: "/api/v1/accounts/456")
    post podcast_feeds_url(podcast), params: {feed: create_params}
    assert_response :forbidden
  end

  test "validates creating feeds" do
    post podcast_feeds_url(podcast), params: {feed: {private: false, slug: nil, title: nil}}
    assert_response :unprocessable_entity
  end

  test "authorize show feed" do
    podcast.update(prx_account_uri: "/api/v1/accounts/456")
    get podcast_feed_url(podcast, feed)
    assert_response :forbidden
  end

  test "should show feed" do
    get podcast_feed_url(podcast, feed)
    assert_response :success
    assert_select "select[name='feed[apple_connection]']", count: 1
    assert_select "input[name='feed[apple_verify_token]']", count: 1

    get podcast_feed_url(podcast, private_feed)
    assert_response :success
    assert_select "select[name='feed[apple_connection]']", count: 0
    assert_select "input[name='feed[apple_verify_token]']", count: 1
    assert_select "select[name='feed[delegated_delivery_config_attributes][show_feed_binding_id]']", count: 1
  end

  test "attaches delegated delivery to a normal feed" do
    key = create(:apple_key, account_id: podcast.account_id)
    podcast.update!(apple_key: key)
    binding = create(:apple_show_feed_binding, feed: feed, apple_show_id: "show-1")

    assert_difference("Apple::DelegatedDeliveryConfig.count", 1) do
      patch podcast_feed_url(podcast, private_feed), params: {
        feed: {
          delegated_delivery_config_attributes: {
            show_feed_binding_id: binding.id,
            publish_enabled: "1",
            sync_blocks_rss: "1"
          }
        }
      }
    end

    assert_redirected_to podcast_feed_url(podcast, private_feed)
    config = private_feed.reload.delegated_delivery_config
    assert_equal binding, config.show_feed_binding
    assert_predicate config, :publish_enabled?
    assert_predicate config, :sync_blocks_rss?
    assert_equal key, config.key
  end

  test "allows a public feed to delegate through its own connection" do
    key = create(:apple_key, account_id: podcast.account_id)
    podcast.update!(apple_key: key)
    binding = create(:apple_show_feed_binding, feed: feed, apple_show_id: "show-1")

    patch podcast_feed_url(podcast, feed), params: {
      feed: {delegated_delivery_config_attributes: {show_feed_binding_id: binding.id, publish_enabled: "1"}}
    }

    assert_redirected_to podcast_feed_url(podcast, feed)
    assert_equal binding, feed.reload.delegated_delivery_config.show_feed_binding
  end

  test "does not offer a connection assigned to another delegated-delivery feed" do
    key = create(:apple_key, account_id: podcast.account_id)
    podcast.update!(apple_key: key)
    binding = create(:apple_show_feed_binding, feed: feed, apple_show_id: "show-1")
    create(:delegated_delivery_config, feed: create(:private_feed, podcast: podcast), show_feed_binding: binding)

    get podcast_feed_url(podcast, private_feed)

    assert_response :success
    assert_select "select[name='feed[delegated_delivery_config_attributes][show_feed_binding_id]'] option[value='#{binding.id}']", count: 0
  end

  test "removes delegated delivery without removing the feed" do
    key = create(:apple_key, account_id: podcast.account_id)
    podcast.update!(apple_key: key)
    binding = create(:apple_show_feed_binding, feed: feed, apple_show_id: "show-1")
    config = create(:delegated_delivery_config, feed: private_feed, show_feed_binding: binding)

    assert_difference("Apple::DelegatedDeliveryConfig.count", -1) do
      patch podcast_feed_url(podcast, private_feed), params: {
        feed: {delegated_delivery_config_attributes: {id: config.id, _destroy: "1"}}
      }
    end

    assert_redirected_to podcast_feed_url(podcast, private_feed)
    assert_predicate private_feed.reload, :persisted?
    assert_nil private_feed.delegated_delivery_config
  end

  test "loads Apple shows with only the selected podcast credential" do
    selected_key = create(:apple_key, account_id: podcast.account_id)
    create(:apple_key, account_id: podcast.account_id)
    podcast.update!(apple_key: selected_key)
    option = Apple::ShowFeedBinding::ConnectionOption.new("Selected show — show-1", "show-1")

    Apple::ShowFeedBinding.stub(:connection_options, ->(apple_key) {
      assert_equal selected_key, apple_key
      [option]
    }) do
      get podcast_feed_url(podcast, feed)
    end

    assert_response :success
    assert_select "select[name='feed[apple_connection]'] option[value='show-1']", text: "Selected show — show-1"
  end

  test "authorize update feed" do
    podcast.update(prx_account_uri: "/api/v1/accounts/456")
    patch podcast_feed_url(podcast, feed), params: {feed: update_params}
    assert_response :forbidden
  end
  test "should block update on locked feed" do
    patch podcast_feed_url(podcast, locked_feed), params: {feed: update_params}
    assert_response :forbidden
  end

  test "should update feed" do
    patch podcast_feed_url(podcast, feed), params: {feed: update_params}
    assert_redirected_to podcast_feed_url(podcast, feed)
  end

  test "connects a public feed to an Apple show" do
    key = create(:apple_key, account_id: podcast.account_id)
    podcast.update!(apple_key: key)
    body = {data: {id: "show-1", type: "shows", attributes: {title: "A show"}}}.to_json
    stub_request(:get, "https://aardvark.prx.org/shows/show-1").to_return(status: 200, body: body)

    patch podcast_feed_url(podcast, feed), params: {
      feed: {apple_connection: "show-1"}
    }

    assert_redirected_to podcast_feed_url(podcast, feed)
    assert_equal "show-1", feed.reload.apple_show_feed_binding.apple_show_id
    assert_equal key, podcast.reload.apple_key
  end

  test "does not connect without a selected podcast credential" do
    patch podcast_feed_url(podcast, feed), params: {
      feed: {apple_connection: "show-1"}
    }

    assert_response :unprocessable_entity
    assert_nil feed.reload.apple_show_feed_binding
  end

  test "does not disconnect a binding used by delegated delivery" do
    key = create(:apple_key, account_id: podcast.account_id)
    podcast.update!(apple_key: key)
    binding = create(:apple_show_feed_binding, feed: feed)
    create(:delegated_delivery_config, feed: private_feed, key: key, show_feed_binding: binding)
    body = {data: [], links: {}}.to_json
    stub_request(:get, "https://aardvark.prx.org/shows").to_return(status: 200, body: body)

    patch podcast_feed_url(podcast, feed), params: {feed: {apple_connection: ""}}

    assert_response :unprocessable_entity
    assert_predicate binding.reload, :persisted?
  end

  test "mirrors legacy routing when replacing the default feed connection" do
    default_feed = podcast.default_feed
    key = create(:apple_key, account_id: podcast.account_id)
    podcast.update!(apple_key: key)
    binding = create(:apple_show_feed_binding, feed: default_feed, apple_show_id: "old-show")
    config = create(:delegated_delivery_config, feed: private_feed, key: key, show_feed_binding: binding)
    body = {data: {id: "new-show", type: "shows", attributes: {title: "New show"}}}.to_json
    stub_request(:get, "https://aardvark.prx.org/shows/new-show").to_return(status: 200, body: body)

    patch podcast_feed_url(podcast, default_feed), params: {
      feed: {apple_connection: "new-show"}
    }

    assert_redirected_to podcast_feed_url(podcast, default_feed)
    assert_equal key, podcast.reload.apple_key
    assert_equal key, config.reload.key
    assert_equal "new-show", private_feed.reload.apple_show_id
  end

  test "validate update feed" do
    patch podcast_feed_url(podcast, feed), params: {feed: {file_name: ""}}
    assert_response :unprocessable_entity
  end

  test "optimistically locks updating feeds" do
    patch podcast_feed_url(podcast, feed), params: {feed: {lock_version: feed.lock_version - 1}}
    assert_response :conflict
  end

  test "should destroy feed" do
    assert podcast
    assert feed
    assert private_feed

    assert_difference("Feed.count", -1) do
      delete podcast_feed_url(podcast, private_feed)
    end

    assert_redirected_to podcast_feed_url(podcast, podcast.default_feed)
  end

  test "authorizes destroying feeds" do
    podcast.update(prx_account_uri: "/api/v1/accounts/456")
    get podcast_feed_url(podcast, feed)
    assert_response :forbidden
  end
end
