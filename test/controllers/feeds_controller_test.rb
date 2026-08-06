require "test_helper"

class FeedsControllerTest < ActionDispatch::IntegrationTest
  let(:podcast) { create(:podcast, prx_account_uri: "/api/v1/accounts/123") }
  let(:feed) { create(:feed, podcast: podcast, private: false) }
  let(:locked_feed) { create(:feed, podcast: podcast, private: false, edit_locked: true) }
  let(:private_feed) { create(:private_feed, podcast: podcast) }
  let(:update_params) { {url: "https://prx.org/a_public_url", display_episodes_count: 5} }
  let(:create_params) { {podcast: podcast, slug: "new_feed", label: "new label", private: false} }

  let(:backfilled_apple_feed) do
    create(:apple_feed, podcast: podcast, apple_show_id: "show-1").tap do |apple_feed|
      apple_feed.update_column(:apple_show_id, nil)
    end
  end

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

  test "selects an uploaded Apple key in the podcast account" do
    podcast.update!(apple_key: create(:apple_key, account_id: podcast.account_id))
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
    assert_equal Feed.last.delegated_delivery_config.key, podcast.reload.apple_key
    assert_nil Feed.last.delegated_delivery_config.show_feed_binding_id
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

  %w[legacy show_feed_binding].each do |routing_source|
    test "warns when Apple rejects the show lookup with #{routing_source} routing" do
      with_apple_routing_source(routing_source) do
        apple_feed = backfilled_apple_feed
        stub_request(:get, "https://aardvark.prx.org/shows").to_return(status: 401, body: "Invalid credentials")

        get podcast_feed_url(podcast, apple_feed)

        assert_response :success
        assert_select '.alert-danger[role="alert"]', text: I18n.t("feeds.form_delegated_delivery_config.show_lookup_failed")
        assert_select 'select[name="feed[apple_show_id]"] option[selected][value="show-1"]', text: "show-1"

        patch podcast_feed_url(podcast, apple_feed), params: {feed: {apple_show_id: "", display_episodes_count: 0}}

        assert_response :unprocessable_entity
        assert_select '.alert-danger[role="alert"]', text: I18n.t("feeds.form_delegated_delivery_config.show_lookup_failed")
        assert_select 'select[name="feed[apple_show_id]"] option[selected][value="show-1"]', count: 0
      end
    end

    test "warns when Apple credentials cannot be decrypted with #{routing_source} routing" do
      with_apple_routing_source(routing_source) do
        apple_feed = backfilled_apple_feed
        failure = -> { raise ActiveRecord::Encryption::Errors::Decryption }
        Apple::Key.stub_any_instance(:key_pem, failure) do
          get podcast_feed_url(podcast, apple_feed)
        end

        assert_response :success
        assert_select '.alert-danger[role="alert"]', text: I18n.t("feeds.form_delegated_delivery_config.show_lookup_failed")
        assert_select 'select[name="feed[apple_show_id]"] option[selected][value="show-1"]', text: "show-1"
      end
    end

    test "leaves the show unselected when lookup fails without a configured show with #{routing_source} routing" do
      with_apple_routing_source(routing_source) do
        apple_feed = Feeds::AppleSubscription.new(podcast: podcast)
        apple_feed.build_delegated_delivery_config(key: build(:apple_key))
        apple_feed.save!
        stub_request(:get, "https://aardvark.prx.org/shows").to_return(status: 401, body: "Invalid credentials")

        get podcast_feed_url(podcast, apple_feed)

        assert_response :success
        assert_select '.alert-danger[role="alert"]', text: I18n.t("feeds.form_delegated_delivery_config.show_lookup_failed")
        assert_select 'select[name="feed[apple_show_id]"] option:not([value=""])', count: 0
      end
    end

    test "does not warn when Apple returns no shows with #{routing_source} routing" do
      with_apple_routing_source(routing_source) do
        apple_feed = backfilled_apple_feed
        stub_request(:get, "https://aardvark.prx.org/shows").to_return(status: 200, body: {data: [], links: {}}.to_json)

        get podcast_feed_url(podcast, apple_feed)

        assert_response :success
        assert_select '.alert-danger[role="alert"]', text: I18n.t("feeds.form_delegated_delivery_config.show_lookup_failed"), count: 0
      end
    end

    test "selects the configured Apple show with #{routing_source} routing" do
      with_apple_routing_source(routing_source) do
        options = [["Configured show", "show-1"], ["Other show", "show-2"]]
        Feeds::AppleSubscription.stub_any_instance(:apple_show_options, options) do
          get podcast_feed_url(podcast, backfilled_apple_feed)
        end

        assert_response :success
        assert_select 'select[name="feed[apple_show_id]"] option[selected]', count: 1 do
          assert_select '[value="show-1"]'
        end
      end
    end

    test "requires a show selection when options are empty with #{routing_source} routing" do
      with_apple_routing_source(routing_source) do
        apple_feed = backfilled_apple_feed

        Feeds::AppleSubscription.stub_any_instance(:apple_show_options, []) do
          get podcast_feed_url(podcast, apple_feed)
        end

        assert_response :success
        assert_select 'select[name="feed[apple_show_id]"][required]' do
          assert_select "option", count: 0
        end

        Feeds::AppleSubscription.stub_any_instance(:apple_show_options, []) do
          patch podcast_feed_url(podcast, apple_feed), params: {feed: {apple_show_id: ""}}
        end

        assert_response :unprocessable_entity
        assert_equal "show-1", apple_feed.delegated_delivery_config.reload.show_feed_binding.apple_show_id
        assert_equal "show-1", podcast.default_feed.reload.apple_sync_log.external_id
      end
    end

    %w[show-1 show-2].each do |selection|
      test "propagates selection #{selection} to both routes with #{routing_source} routing" do
        with_apple_routing_source(routing_source) do
          apple_feed = backfilled_apple_feed

          patch podcast_feed_url(podcast, apple_feed), params: {feed: {apple_show_id: selection}}

          assert_redirected_to podcast_feed_url(podcast, apple_feed)
          assert_equal selection, apple_feed.reload.apple_show_id
          assert_equal selection, apple_feed.delegated_delivery_config.show_feed_binding.apple_show_id
          assert_equal selection, podcast.default_feed.reload.apple_sync_log.external_id
        end
      end
    end

    ["show-2", ""].each do |selection|
      test "preserves submitted show #{selection.inspect} on validation failure with #{routing_source} routing" do
        with_apple_routing_source(routing_source) do
          apple_feed = backfilled_apple_feed
          options = [["Configured show", "show-1"], ["Other show", "show-2"]]

          Feeds::AppleSubscription.stub_any_instance(:apple_show_options, options) do
            patch podcast_feed_url(podcast, apple_feed), params: {
              feed: {apple_show_id: selection, display_episodes_count: 0}
            }
          end

          assert_response :unprocessable_entity
          assert_select 'select[name="feed[apple_show_id]"]' do
            assert_select 'option[value="show-2"]'
            if selection.present?
              assert_select "option[selected][value='#{selection}']"
            else
              assert_select 'option[selected][value="show-1"]', count: 0
              assert_select 'option[selected][value="show-2"]', count: 0
            end
          end
          assert_equal "show-1", apple_feed.delegated_delivery_config.reload.apple_show_id
        end
      end
    end
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
    create(:apple_config, feed: private_feed, key: key, show_feed_binding: binding)
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
    config = create(:apple_config, feed: private_feed, key: key, show_feed_binding: binding)
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

  private def with_apple_routing_source(source)
    previous = ENV["APPLE_ROUTING_SOURCE"]
    ENV["APPLE_ROUTING_SOURCE"] = source
    yield
  ensure
    previous ? ENV["APPLE_ROUTING_SOURCE"] = previous : ENV.delete("APPLE_ROUTING_SOURCE")
  end
end
