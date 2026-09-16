require "test_helper"

class FeedsControllerTest < ActionDispatch::IntegrationTest
  let(:podcast) { create(:podcast, prx_account_uri: "/api/v1/accounts/123") }
  let(:feed) { create(:feed, podcast: podcast, private: false) }
  let(:locked_feed) { create(:feed, podcast: podcast, private: false, edit_locked: true) }
  let(:private_feed) { create(:private_feed, podcast: podcast) }
  let(:update_params) { {url: "https://prx.org/a_public_url", display_episodes_count: 5} }
  let(:create_params) { {podcast: podcast, slug: "new_feed", label: "new label", private: false} }

  let(:connected_apple_feed) do
    podcast.update!(apple_key: create(:apple_key, account_id: podcast.account_id))
    create(:apple_show_feed_binding, feed: feed, apple_show_id: "show-1")
    feed
  end

  setup_current_user { build(:user, account_id: 123) }

  test "prepares optional delivery fields without attaching a configuration" do
    Feed.stub_any_instance(:build_delegated_delivery_config, ->(*) { flunk "Form setup attached a delivery config" }) do
      get podcast_feed_url(podcast, private_feed)
    end

    assert_response :success
    assert_select 'select[name="feed[delegated_delivery_config_attributes][show_feed_binding_id]"]'
    assert_nil private_feed.reload.delegated_delivery_config
    assert_nil private_feed.integration_type
  end

  test "should get new" do
    get new_podcast_feed_url(podcast)
    assert_response :success
  end

  test "prepares configuration fields for a new Megaphone feed" do
    get new_megaphone_podcast_feeds_url(podcast)

    assert_response :success
    assert_select 'input[name="feed[megaphone_config_attributes][organization_id]"]'
    assert_select 'input[name="feed[megaphone_config_attributes][token]"]'
    assert_select 'input[name="feed[megaphone_config_attributes][network_id]"]'
  end

  test "loads the feed form without calling Apple and retains the connection until the frame loads" do
    connected_apple_feed

    get podcast_feed_url(podcast, feed)

    assert_response :success
    assert_not_requested :get, "https://aardvark.prx.org/shows"
    assert_select "form turbo-frame#apple_connection_feed_#{feed.id}[loading='lazy'][src]" do
      assert_select 'select[name="feed[apple_connection]"][disabled]'
      assert_select 'input[type="hidden"][name="feed[apple_connection]"][value="show-1"]'
    end

    patch podcast_feed_url(podcast, feed), params: {feed: {title: "Changed", apple_connection: "show-1"}}

    assert_redirected_to podcast_feed_url(podcast, feed)
    assert_equal "Changed", feed.reload.title
    assert_equal "show-1", feed.apple_show_feed_binding.apple_show_id
    assert_not_requested :get, "https://aardvark.prx.org/shows"
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

  test "renders and updates delegated delivery settings" do
    apple_feed = create(:apple_feed, podcast: podcast)
    config = apple_feed.delegated_delivery_config

    get podcast_feed_url(podcast, apple_feed)

    assert_response :success
    assert_select 'input[type="checkbox"][name="feed[delegated_delivery_config_attributes][publish_enabled]"]'
    assert_select 'select[name="feed[delegated_delivery_config_attributes][show_feed_binding_id]"][required]'

    patch podcast_feed_url(podcast, apple_feed), params: {
      feed: {
        delegated_delivery_config_attributes: {id: config.id, publish_enabled: "0", sync_blocks_rss: "0"}
      }
    }

    assert_redirected_to podcast_feed_url(podcast, apple_feed)
    refute config.reload.publish_enabled
    refute config.sync_blocks_rss
  end

  ["show-2", ""].each do |selection|
    test "preserves submitted connection #{selection.inspect} on validation failure" do
      apple_feed = connected_apple_feed
      options = [
        Apple::ShowFeedBinding::ConnectionOption.new("Configured show", "show-1"),
        Apple::ShowFeedBinding::ConnectionOption.new("Other show", "show-2")
      ]

      patch podcast_feed_url(podcast, apple_feed), params: {
        feed: {apple_connection: selection, display_episodes_count: 0}
      }

      assert_response :unprocessable_entity
      assert_select 'input[type="hidden"][name="feed[apple_connection]"]' do |fields|
        assert_equal selection, fields.first["value"].to_s
      end
      frame_url = css_select("turbo-frame[src]").find { |frame| frame["id"] == "apple_connection_feed_#{feed.id}" }["src"]
      assert_equal selection, Rack::Utils.parse_nested_query(URI(frame_url).query)["selection"]
      assert_not_requested :get, "https://aardvark.prx.org/shows"

      Apple::ShowFeedBinding.stub(:connection_options, options) { get frame_url }

      assert_response :success
      assert_select 'select[name="feed[apple_connection]"]' do
        assert_select "option[value='show-2']"
        if selection.present?
          assert_select "option[selected][value='#{selection}']"
        else
          assert_select 'option[selected][value="show-1"]', count: 0
          assert_select 'option[selected][value="show-2"]', count: 0
        end
      end
      assert_equal "show-1", apple_feed.reload.apple_show_feed_binding.apple_show_id
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

  test "allows metadata edits without selecting optional delegated delivery" do
    key = create(:apple_key, account_id: podcast.account_id)
    podcast.update!(apple_key: key)
    binding = create(:apple_show_feed_binding, feed: feed)

    get podcast_feed_url(podcast, private_feed)

    assert_response :success
    assert_select 'select[name="feed[delegated_delivery_config_attributes][show_feed_binding_id]"]' do
      assert_select "option[value='#{binding.id}']"
      assert_select 'option[value=""]'
    end
    assert_select 'select[name="feed[delegated_delivery_config_attributes][show_feed_binding_id]"][required]', count: 0

    assert_no_difference "Apple::DelegatedDeliveryConfig.count" do
      patch podcast_feed_url(podcast, private_feed), params: {
        feed: {
          title: "Updated title",
          delegated_delivery_config_attributes: {show_feed_binding_id: "", publish_enabled: "0", sync_blocks_rss: "0"}
        }
      }
    end

    assert_redirected_to podcast_feed_url(podcast, private_feed)
    assert_equal "Updated title", private_feed.reload.title
    assert_nil private_feed.delegated_delivery_config
  end

  test "preserves submitted delivery settings when feed validation fails" do
    binding = create(:apple_show_feed_binding, feed: feed)

    patch podcast_feed_url(podcast, private_feed), params: {
      feed: {
        file_name: "",
        delegated_delivery_config_attributes: {show_feed_binding_id: binding.id, publish_enabled: "0"}
      }
    }

    assert_response :unprocessable_entity
    assert_select 'select[name="feed[delegated_delivery_config_attributes][show_feed_binding_id]"]' do
      assert_select "option[selected][value='#{binding.id}']"
    end
    assert_select 'input[type="checkbox"][name="feed[delegated_delivery_config_attributes][publish_enabled]"]:not([checked])'
    assert_nil private_feed.reload.delegated_delivery_config
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
    assert_select '.card-body > .alert-danger[role="alert"]', text: /must be selected for the feed's podcast/
    assert_nil feed.reload.apple_show_feed_binding
  end

  test "keeps connection errors outside the frame that reloads the dropdown" do
    connected_apple_feed
    stub_request(:get, "https://aardvark.prx.org/shows/show-2").to_return(status: 403, body: "{}")

    patch podcast_feed_url(podcast, feed), params: {feed: {apple_connection: "show-2"}}

    assert_response :unprocessable_entity
    assert_select '.card-body > .alert-danger[role="alert"]', text: /could not be read with the selected Apple credential/ do |alerts|
      assert_empty alerts.first.ancestors("turbo-frame")
    end
    assert_select "turbo-frame#apple_connection_feed_#{feed.id}[src]"
    assert_equal "show-1", feed.reload.apple_show_feed_binding.apple_show_id
  end

  test "explains when an Apple show is already connected without repeating field names" do
    connected_apple_feed
    other_feed = create(:public_feed, podcast: podcast)
    create(:apple_show_feed_binding, feed: other_feed, apple_show_id: "show-2")

    patch podcast_feed_url(podcast, feed), params: {feed: {apple_connection: "show-2"}}

    assert_response :unprocessable_entity
    assert_select '.card-body > .alert-danger[role="alert"]', text: "Apple show is already connected to another feed"
    assert_equal "show-1", feed.reload.apple_show_feed_binding.apple_show_id
  end

  test "does not disconnect a binding used by delegated delivery" do
    key = create(:apple_key, account_id: podcast.account_id)
    podcast.update!(apple_key: key)
    binding = create(:apple_show_feed_binding, feed: feed)
    create(:delegated_delivery_config, feed: private_feed, key: key, show_feed_binding: binding)

    patch podcast_feed_url(podcast, feed), params: {feed: {apple_connection: ""}}

    assert_response :unprocessable_entity
    assert_predicate binding.reload, :persisted?
    assert_not_requested :get, "https://aardvark.prx.org/shows"
  end

  test "does not make a connected public feed private" do
    connected_apple_feed

    patch podcast_feed_url(podcast, feed), params: {feed: {private: "1"}}

    assert_response :unprocessable_entity
    refute feed.reload.private?
    assert_equal "show-1", feed.apple_show_feed_binding.apple_show_id
  end

  test "renders the connection and error when delegated delivery prevents deletion" do
    connected_apple_feed
    binding = feed.apple_show_feed_binding
    config = create(:delegated_delivery_config, feed: private_feed, key: podcast.apple_key, show_feed_binding: binding)

    delete podcast_feed_url(podcast, feed)

    assert_response :unprocessable_entity
    assert_includes response.body, "Cannot delete a feed while delegated delivery uses its Apple connection"
    assert_select 'select[name="feed[apple_connection]"] option[selected][value="show-1"]'
    assert_nil feed.reload.deleted_at
    assert_equal binding, config.reload.show_feed_binding
    assert_not_requested :get, "https://aardvark.prx.org/shows"
  end

  test "mirrors legacy routing when replacing the default feed connection" do
    default_feed = podcast.default_feed
    key = create(:apple_key, account_id: podcast.account_id)
    podcast.update!(apple_key: key)
    binding = create(:apple_show_feed_binding, feed: default_feed, apple_show_id: "old-show")
    config = create(:delegated_delivery_config, feed: private_feed, key: key, show_feed_binding: binding)
    sync_log = Apple::SyncLog.log!(feeder_id: default_feed.id, feeder_type: :feeds, external_id: "old-show")
    body = {data: {id: "new-show", type: "shows", attributes: {title: "New show"}}}.to_json
    stub_request(:get, "https://aardvark.prx.org/shows/new-show").to_return(status: 200, body: body)

    patch podcast_feed_url(podcast, default_feed), params: {
      feed: {apple_connection: "new-show"}
    }

    assert_redirected_to podcast_feed_url(podcast, default_feed)
    assert_equal key, podcast.reload.apple_key
    assert_equal key, config.reload.key
    assert_equal "new-show", private_feed.reload.apple_show_id
    assert_equal "new-show", sync_log.reload.external_id
    Apple::DelegatedDeliveryConfig.stub(:routing_source, :legacy) do
      assert_equal "new-show", config.reload.apple_show_id
      assert_equal "new-show", config.build_show.apple_id
    end
  end

  test "mirrors a default feed connection before delegated delivery is configured" do
    default_feed = podcast.default_feed
    podcast.update!(apple_key: create(:apple_key, account_id: podcast.account_id))
    body = {data: {id: "new-show", type: "shows", attributes: {title: "New show"}}}.to_json
    stub_request(:get, "https://aardvark.prx.org/shows/new-show").to_return(status: 200, body: body)

    patch podcast_feed_url(podcast, default_feed), params: {feed: {apple_connection: "new-show"}}

    assert_redirected_to podcast_feed_url(podcast, default_feed)
    assert_equal "new-show", default_feed.reload.apple_sync_log.external_id
    assert_nil default_feed.delegated_delivery_config
  end

  test "rolls back the connection and sync log when legacy mirroring fails" do
    default_feed = podcast.default_feed
    key = create(:apple_key, account_id: podcast.account_id)
    podcast.update!(apple_key: key)
    binding = create(:apple_show_feed_binding, feed: default_feed, apple_show_id: "old-show")
    create(:delegated_delivery_config, feed: private_feed, key: key, show_feed_binding: binding)
    sync_log = Apple::SyncLog.log!(feeder_id: default_feed.id, feeder_type: :feeds, external_id: "old-show")
    original_title = default_feed.title
    body = {data: {id: "new-show", type: "shows", attributes: {title: "New show"}}}.to_json
    stub_request(:get, "https://aardvark.prx.org/shows/new-show").to_return(status: 200, body: body)

    failure = ActiveRecord::RecordInvalid.new(private_feed)
    Feed.stub_any_instance(:update!, ->(*) { raise failure }) do
      assert_raises ActiveRecord::RecordInvalid do
        patch podcast_feed_url(podcast, default_feed), params: {
          feed: {apple_connection: "new-show", title: "Changed title"}
        }
      end
    end

    assert_equal original_title, default_feed.reload.title
    assert_equal "old-show", binding.reload.apple_show_id
    assert_equal "old-show", private_feed.reload.apple_show_id
    assert_equal "old-show", sync_log.reload.external_id
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
