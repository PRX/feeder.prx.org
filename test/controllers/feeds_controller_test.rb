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
    assert_select ".card-title", text: I18n.t("feeds.form_apple_settings.title"), count: 1 do |titles|
      assert_select titles.first.ancestors(".card").first, '.card-footer time[data-local="time-ago"]', count: 1
    end
    assert_not_requested :get, "https://aardvark.prx.org/shows"
    assert_select "form turbo-frame#apple_connection_feed_#{feed.id}[loading='lazy'][src]" do
      assert_select 'select[name="feed[apple_settings][connection]"][disabled]'
      assert_select 'input[type="hidden"][name="feed[apple_settings][connection]"][value="show-1"]'
    end

    patch podcast_feed_url(podcast, feed), params: {feed: {title: "Changed", apple_settings: {connection: "show-1"}}}

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
    assert_select ".card-title", text: I18n.t("feeds.form_apple_settings.title"), count: 1 do |titles|
      assert_select titles.first.ancestors(".card").first, '.card-footer time[data-local="time-ago"]', count: 1
    end
    assert_select 'input[type="checkbox"][name="feed[apple_settings][publish_enabled]"]'
    assert_select 'select[name="feed[apple_settings][delivery]"]'

    patch podcast_feed_url(podcast, apple_feed), params: {
      feed: {apple_settings: {publish_enabled: "0", sync_blocks_rss: "0"}}
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
        feed: {display_episodes_count: 0, apple_settings: {connection: selection}}
      }

      assert_response :unprocessable_entity
      assert_select 'input[type="hidden"][name="feed[apple_settings][connection]"]' do |fields|
        assert_equal selection, fields.first["value"].to_s
      end
      frame_url = css_select("turbo-frame[src]").find { |frame| frame["id"] == "apple_connection_feed_#{feed.id}" }["src"]
      assert_equal selection, Rack::Utils.parse_nested_query(URI(frame_url).query)["selection"]
      assert_not_requested :get, "https://aardvark.prx.org/shows"

      Apple::ShowFeedBinding.stub(:connection_options, options) { get frame_url }

      assert_response :success
      assert_select 'select[name="feed[apple_settings][connection]"]' do
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
    assert_select "select[name='feed[apple_settings][connection]']", count: 1
    assert_select "input[name='feed[apple_verify_token]']", count: 1

    get podcast_feed_url(podcast, private_feed)
    assert_response :success
    assert_select "[data-apple-settings-target='ownShowOnly'].d-none" do
      assert_select "select[name='feed[apple_settings][connection]']", count: 1
      assert_select "input[name='feed[apple_verify_token]']", count: 1
    end
    assert_select "input[name='feed[apple_verify_token]']", count: 1
    assert_select "select[name='feed[apple_settings][delivery]'] option[selected][value='']"
    assert_select "select[name='feed[apple_settings][delivery]']", count: 1
  end

  test "shows only the connection section on the default feed" do
    get podcast_feed_url(podcast, podcast.default_feed)

    assert_response :success
    assert_select "select[name='feed[apple_settings][connection]']", count: 1
    assert_select "select[name='feed[apple_settings][delivery]']", count: 0
  end

  test "attaches delegated delivery to a normal feed" do
    key = create(:apple_key, account_id: podcast.account_id)
    podcast.update!(apple_key: key)
    binding = create(:apple_show_feed_binding, feed: feed, apple_show_id: "show-1")

    assert_difference("Apple::DelegatedDeliveryConfig.count", 1) do
      patch podcast_feed_url(podcast, private_feed), params: {
        feed: {apple_settings: {delivery: binding.id, publish_enabled: "1", sync_blocks_rss: "1"}}
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
    assert_select 'select[name="feed[apple_settings][delivery]"]' do
      assert_select "option[value='#{binding.id}']"
      assert_select 'option[value=""]'
    end
    assert_select 'select[name="feed[apple_settings][delivery]"][required]', count: 0

    assert_no_difference "Apple::DelegatedDeliveryConfig.count" do
      patch podcast_feed_url(podcast, private_feed), params: {
        feed: {title: "Updated title", apple_settings: {publish_enabled: "0", sync_blocks_rss: "0"}}
      }
    end

    assert_redirected_to podcast_feed_url(podcast, private_feed)
    assert_equal "Updated title", private_feed.reload.title
    assert_nil private_feed.delegated_delivery_config
    assert_empty private_feed.integration_types
  end

  test "preserves submitted delivery settings when feed validation fails" do
    binding = create(:apple_show_feed_binding, feed: feed)

    patch podcast_feed_url(podcast, private_feed), params: {
      feed: {file_name: "", apple_settings: {delivery: binding.id, publish_enabled: "0"}}
    }

    assert_response :unprocessable_entity
    assert_select 'select[name="feed[apple_settings][delivery]"]' do
      assert_select "option[selected][value='#{binding.id}']"
    end
    assert_select 'input[type="checkbox"][name="feed[apple_settings][publish_enabled]"]:not([checked])'
    assert_nil private_feed.reload.delegated_delivery_config
  end

  test "allows a public feed to delegate through its own connection" do
    key = create(:apple_key, account_id: podcast.account_id)
    podcast.update!(apple_key: key)
    binding = create(:apple_show_feed_binding, feed: feed, apple_show_id: "show-1")

    patch podcast_feed_url(podcast, feed), params: {
      feed: {apple_settings: {delivery: "own", connection: "show-1", publish_enabled: "1"}}
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
    assert_select "select[name='feed[apple_settings][delivery]'] option[value='#{binding.id}']", count: 0
  end

  test "removes delegated delivery when none is chosen" do
    apple_feed = create(:apple_feed, podcast: podcast)
    config = apple_feed.delegated_delivery_config
    binding = config.show_feed_binding

    assert_difference("Apple::DelegatedDeliveryConfig.count", -1) do
      patch podcast_feed_url(podcast, apple_feed), params: {
        feed: {apple_settings: {delivery: ""}}
      }
    end

    assert_redirected_to podcast_feed_url(podcast, apple_feed)
    assert_nil apple_feed.reload.delegated_delivery_config
    assert_predicate binding.reload, :persisted?
  end

  test "rejects delivery through another podcast's show" do
    apple_feed = create(:apple_feed, podcast: podcast)
    config = apple_feed.delegated_delivery_config
    binding = config.show_feed_binding
    other_binding = create(:apple_show_feed_binding, apple_show_id: "other-show")

    patch podcast_feed_url(podcast, apple_feed), params: {
      feed: {apple_settings: {delivery: other_binding.id}}
    }

    assert_response :unprocessable_entity
    assert_select ".invalid-feedback", text: /must be this feed's own apple show or a public feed on this podcast/i
    assert_equal binding, config.reload.show_feed_binding
  end

  test "rejects an unknown delivery" do
    apple_feed = create(:apple_feed, podcast: podcast)

    patch podcast_feed_url(podcast, apple_feed), params: {feed: {apple_settings: {delivery: "sideways"}}}

    assert_response :unprocessable_entity
    assert_predicate apple_feed.reload.delegated_delivery_config, :present?
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
      feed: {apple_settings: {connection: "show-1"}}
    }

    assert_redirected_to podcast_feed_url(podcast, feed)
    assert_equal "show-1", feed.reload.apple_show_feed_binding.apple_show_id
    assert_equal key, podcast.reload.apple_key
  end

  def stub_apple_show(show_id)
    body = {data: {id: show_id, type: "shows", attributes: {title: "A show"}}}.to_json
    stub_request(:get, "https://aardvark.prx.org/shows/#{show_id}").to_return(status: 200, body: body)
  end

  test "connects a private feed's own Apple show and delivers through it in one save" do
    podcast.update!(apple_key: create(:apple_key, account_id: podcast.account_id))
    stub_apple_show("show-9")

    patch podcast_feed_url(podcast, private_feed), params: {
      feed: {apple_settings: {delivery: "own", connection: "show-9", publish_enabled: "1", sync_blocks_rss: "0"}}
    }

    assert_redirected_to podcast_feed_url(podcast, private_feed)
    binding = private_feed.reload.apple_show_feed_binding
    assert_equal "show-9", binding.apple_show_id
    config = private_feed.delegated_delivery_config
    assert_equal binding, config.show_feed_binding
    assert_predicate config, :publish_enabled?
    refute config.sync_blocks_rss?
  end

  test "requires a show to publish to this feed's own Apple show" do
    podcast.update!(apple_key: create(:apple_key, account_id: podcast.account_id))

    assert_no_difference(["Apple::DelegatedDeliveryConfig.count", "Apple::ShowFeedBinding.count"]) do
      patch podcast_feed_url(podcast, private_feed), params: {
        feed: {apple_settings: {delivery: "own", connection: "", publish_enabled: "1"}}
      }
    end

    assert_response :unprocessable_entity
    assert_select ".alert-danger", text: "must be selected to publish to this feed's own Apple show"
    assert_select "select[name='feed[apple_settings][delivery]'] option[selected][value='own']"
  end

  test "explains when another feed already delivers through a public feed's own show" do
    podcast.update!(apple_key: create(:apple_key, account_id: podcast.account_id))
    binding = create(:apple_show_feed_binding, feed: feed, apple_show_id: "show-1")
    config = create(:delegated_delivery_config, feed: private_feed, show_feed_binding: binding)

    assert_no_difference("Apple::DelegatedDeliveryConfig.count") do
      patch podcast_feed_url(podcast, feed), params: {
        feed: {apple_settings: {delivery: "own", connection: "show-1", publish_enabled: "1"}}
      }
    end

    assert_response :unprocessable_entity
    assert_select ".card-body > .alert-danger", text: /already used for delegated delivery by #{Regexp.escape(private_feed.label)}/
    assert_no_match(/has already been taken/i, response.body)
    assert_equal private_feed, config.reload.feed
  end

  test "confirms before a private feed leaves its own show" do
    podcast.update!(apple_key: create(:apple_key, account_id: podcast.account_id))
    binding = create(:apple_show_feed_binding, feed: private_feed, apple_show_id: "show-9")
    create(:delegated_delivery_config, feed: private_feed, show_feed_binding: binding)

    get podcast_feed_url(podcast, private_feed)

    assert_response :success
    assert_select "select[name='feed[apple_settings][delivery]'][data-confirm-field-target='field']" do |fields|
      assert_equal I18n.t("feeds.form_apple_settings.confirm_leave_own_show"), fields.first["data-confirm-with"]
      assert_includes fields.first["data-action"].split, "apple-settings#sync"
    end
  end

  test "shows the verify token with a private feed's own show" do
    podcast.update!(apple_key: create(:apple_key, account_id: podcast.account_id))
    binding = create(:apple_show_feed_binding, feed: private_feed, apple_show_id: "show-9")
    create(:delegated_delivery_config, feed: private_feed, show_feed_binding: binding)

    get podcast_feed_url(podcast, private_feed)

    assert_response :success
    assert_select "[data-apple-settings-target='ownShowOnly']:not(.d-none) input[name='feed[apple_verify_token]']", count: 1
  end

  test "does not confirm the delivery without an own show connection" do
    get podcast_feed_url(podcast, private_feed)

    assert_response :success
    assert_select "select[name='feed[apple_settings][delivery]']", count: 1
    assert_select "select[name='feed[apple_settings][delivery]'][data-confirm-field-target]", count: 0
  end

  test "removes a private feed's own show when its delivery is cleared" do
    podcast.update!(apple_key: create(:apple_key, account_id: podcast.account_id))
    binding = create(:apple_show_feed_binding, feed: private_feed, apple_show_id: "show-9")
    create(:delegated_delivery_config, feed: private_feed, show_feed_binding: binding)

    patch podcast_feed_url(podcast, private_feed), params: {
      feed: {apple_settings: {delivery: "", connection: "show-9"}}
    }

    assert_redirected_to podcast_feed_url(podcast, private_feed)
    assert_nil private_feed.reload.delegated_delivery_config
    assert_nil private_feed.apple_show_feed_binding
  end

  test "maps a private feed from its own show to a public feed" do
    podcast.update!(apple_key: create(:apple_key, account_id: podcast.account_id))
    public_binding = create(:apple_show_feed_binding, feed: feed, apple_show_id: "show-1")
    own_binding = create(:apple_show_feed_binding, feed: private_feed, apple_show_id: "show-9")
    config = create(:delegated_delivery_config, feed: private_feed, show_feed_binding: own_binding)

    patch podcast_feed_url(podcast, private_feed), params: {
      feed: {apple_settings: {connection: "show-9", delivery: public_binding.id}}
    }

    assert_redirected_to podcast_feed_url(podcast, private_feed)
    assert_equal public_binding, config.reload.show_feed_binding
    assert_nil private_feed.reload.apple_show_feed_binding
  end

  test "disconnects a public feed mapped to another public feed's show" do
    podcast.update!(apple_key: create(:apple_key, account_id: podcast.account_id))
    public_binding = create(:apple_show_feed_binding, feed: feed, apple_show_id: "show-1")
    other_feed = create(:feed, podcast: podcast, private: false)
    own_binding = create(:apple_show_feed_binding, feed: other_feed, apple_show_id: "show-2")
    config = create(:delegated_delivery_config, feed: other_feed, show_feed_binding: own_binding)

    patch podcast_feed_url(podcast, other_feed), params: {
      feed: {apple_settings: {connection: "show-2", delivery: public_binding.id}}
    }

    assert_redirected_to podcast_feed_url(podcast, other_feed)
    assert_equal public_binding, config.reload.show_feed_binding
    assert_nil other_feed.reload.apple_show_feed_binding
    refute Apple::ShowFeedBinding.exists?(own_binding.id)
  end

  test "hides a mapped public feed's connection" do
    public_binding = create(:apple_show_feed_binding, feed: feed, apple_show_id: "show-1")
    other_feed = create(:feed, podcast: podcast, private: false)
    create(:apple_show_feed_binding, feed: other_feed, apple_show_id: "show-2")
    create(:delegated_delivery_config, feed: other_feed, show_feed_binding: public_binding)

    get podcast_feed_url(podcast, other_feed)

    assert_response :success
    assert_select "[data-apple-settings-target='connectedOnly'].d-none" do
      assert_select "select[name='feed[apple_settings][connection]']", count: 1
      assert_select "input[name='feed[apple_verify_token]']", count: 0
    end
    assert_select "input[name='feed[apple_verify_token]']", count: 1
  end

  test "keeps a public feed connected when another feed delivers to its show" do
    podcast.update!(apple_key: create(:apple_key, account_id: podcast.account_id))
    public_binding = create(:apple_show_feed_binding, feed: feed, apple_show_id: "show-1")
    other_feed = create(:feed, podcast: podcast, private: false)
    own_binding = create(:apple_show_feed_binding, feed: other_feed, apple_show_id: "show-2")
    create(:delegated_delivery_config, feed: private_feed, show_feed_binding: own_binding)

    assert_no_difference("Apple::DelegatedDeliveryConfig.count") do
      patch podcast_feed_url(podcast, other_feed), params: {
        feed: {apple_settings: {connection: "show-2", delivery: public_binding.id}}
      }
    end

    assert_response :unprocessable_entity
    assert_select ".card-body > .alert-danger", text: /cannot be removed while delegated-delivery feeds use it/i
    assert_equal own_binding, other_feed.reload.apple_show_feed_binding
    assert_nil other_feed.delegated_delivery_config
  end

  test "disconnects a public feed when its own delivery is removed" do
    podcast.update!(apple_key: create(:apple_key, account_id: podcast.account_id))
    binding = create(:apple_show_feed_binding, feed: feed, apple_show_id: "show-1")
    create(:delegated_delivery_config, feed: feed, show_feed_binding: binding)

    get podcast_feed_url(podcast, feed)
    assert_select "select[name='feed[apple_settings][delivery]'] option[selected][value='own']"
    assert_select "[data-apple-settings-target='connectedOnly']:not(.d-none) select[name='feed[apple_settings][connection]']"
    assert_select "[data-apple-settings-delivery-was-value='own'][data-apple-settings-private-value='false']"

    patch podcast_feed_url(podcast, feed), params: {
      feed: {apple_settings: {delivery: "", connection: "show-1"}}
    }

    assert_redirected_to podcast_feed_url(podcast, feed)
    assert_nil feed.reload.delegated_delivery_config
    assert_nil feed.apple_show_feed_binding
    refute Apple::ShowFeedBinding.exists?(binding.id)
  end

  test "keeps a connected public feed without delivery connected when saved" do
    podcast.update!(apple_key: create(:apple_key, account_id: podcast.account_id))
    binding = create(:apple_show_feed_binding, feed: feed, apple_show_id: "show-1")

    get podcast_feed_url(podcast, feed)
    assert_select "select[name='feed[apple_settings][delivery]'] option[selected][value='']"
    assert_select "[data-apple-settings-target='connectedOnly']:not(.d-none) select[name='feed[apple_settings][connection]']"

    patch podcast_feed_url(podcast, feed), params: {
      feed: {title: "Changed", apple_settings: {delivery: "", connection: "show-1"}}
    }

    assert_redirected_to podcast_feed_url(podcast, feed)
    assert_equal "Changed", feed.reload.title
    assert_equal binding, feed.apple_show_feed_binding
  end

  test "shows the mapped public feed's show and links to it" do
    binding = create(:apple_show_feed_binding, feed: feed, apple_show_id: "show-1")
    create(:delegated_delivery_config, feed: private_feed, show_feed_binding: binding)

    get podcast_feed_url(podcast, private_feed)

    assert_response :success
    assert_select "select[name='feed[apple_settings][delivery]'] option[selected][value='#{binding.id}']", text: "#{feed.label} (show-1)"
    assert_select "[data-apple-settings-target='mappedOnly']:not(.d-none) a[href='#{podcast_feed_path(podcast, feed)}'][data-apple-settings-target='mappedLink']", text: /#{I18n.t("feeds.form_apple_settings.view_mapped_feed")}/
  end

  test "keeps a mapping to a feed that is no longer available for delivery" do
    binding = create(:apple_show_feed_binding, feed: feed, apple_show_id: "show-1")
    config = create(:delegated_delivery_config, feed: private_feed, show_feed_binding: binding)
    feed.update_column(:private, true)

    get podcast_feed_url(podcast, private_feed)
    assert_select "select[name='feed[apple_settings][delivery]'] option[selected][value='#{binding.id}']"

    patch podcast_feed_url(podcast, private_feed), params: {
      feed: {apple_settings: {delivery: binding.id}}
    }

    assert_redirected_to podcast_feed_url(podcast, private_feed)
    assert_equal binding, config.reload.show_feed_binding
  end

  test "does not treat a private feed mapped to a public feed as its own show" do
    podcast.update!(apple_key: create(:apple_key, account_id: podcast.account_id))
    public_binding = create(:apple_show_feed_binding, feed: feed, apple_show_id: "show-1")
    create(:apple_show_feed_binding, feed: private_feed, apple_show_id: "show-9")
    create(:delegated_delivery_config, feed: private_feed, show_feed_binding: public_binding)

    get podcast_feed_url(podcast, private_feed)

    assert_response :success
    assert_select "select[name='feed[apple_settings][delivery]'] option[selected][value='#{public_binding.id}']"
  end

  test "hides publishing settings until a delivery is chosen" do
    get podcast_feed_url(podcast, private_feed)

    assert_response :success
    assert_select "[data-apple-settings-target='deliverySettings'].d-none" do
      assert_select "input[type='checkbox'][name='feed[apple_settings][publish_enabled]']"
      assert_select "input[type='checkbox'][name='feed[apple_settings][sync_blocks_rss]']"
    end
  end

  test "shows publishing settings for a mapped feed and a feed on its own show" do
    binding = create(:apple_show_feed_binding, feed: feed, apple_show_id: "show-1")
    create(:delegated_delivery_config, feed: private_feed, show_feed_binding: binding)
    other_feed = create(:feed, podcast: podcast, private: false)
    own_binding = create(:apple_show_feed_binding, feed: other_feed, apple_show_id: "show-2")
    create(:delegated_delivery_config, feed: other_feed, show_feed_binding: own_binding)

    [private_feed, other_feed].each do |shown_feed|
      get podcast_feed_url(podcast, shown_feed)

      assert_response :success
      assert_select "[data-apple-settings-target='deliverySettings']:not(.d-none)" do
        assert_select "input[type='checkbox'][name='feed[apple_settings][publish_enabled]']"
      end
    end
  end

  test "points a connected public feed without mappings at its own show" do
    create(:apple_show_feed_binding, feed: feed, apple_show_id: "show-1")

    get podcast_feed_url(podcast, feed)

    assert_response :success
    assert_select ".alert-info[role='status']", text: I18n.t("feeds.form_apple_settings.no_mappings_own_show")
    assert_select ".alert-info[role='status']", text: I18n.t("feeds.form_apple_settings.no_mappings"), count: 0
  end

  test "suggests connecting a public feed when a feed has no mappings or connection" do
    get podcast_feed_url(podcast, private_feed)

    assert_response :success
    assert_select ".alert-info[role='status']", text: I18n.t("feeds.form_apple_settings.no_mappings")
  end

  test "lists feeds mapped to a public feed's connection" do
    binding = create(:apple_show_feed_binding, feed: feed, apple_show_id: "show-1")
    create(:delegated_delivery_config, feed: private_feed, show_feed_binding: binding, publish_enabled: false)

    get podcast_feed_url(podcast, feed)

    assert_response :success
    assert_select "h3", text: I18n.t("feeds.form_apple_settings.mapped_feed")
    assert_select "a[href='#{podcast_feed_path(podcast, private_feed)}']", text: private_feed.label
    assert_select ".badge", text: I18n.t("feeds.form_apple_settings.paused")
    assert_select "a", text: I18n.t("feeds.form_apple_settings.create_feed"), count: 0
  end

  test "offers to create a feed mapped to a public feed's free show" do
    binding = create(:apple_show_feed_binding, feed: feed, apple_show_id: "show-1")

    get podcast_feed_url(podcast, feed)

    assert_response :success
    path = new_podcast_feed_path(podcast, feed: {apple_settings: {delivery: binding.id}})
    assert_select "a[href='#{path}']", text: I18n.t("feeds.form_apple_settings.create_feed")
  end

  test "does not offer mapped feeds when a public feed delivers through its own show" do
    binding = create(:apple_show_feed_binding, feed: feed, apple_show_id: "show-1")
    create(:delegated_delivery_config, feed: feed, show_feed_binding: binding)

    get podcast_feed_url(podcast, feed)

    assert_response :success
    assert_select "h3", text: I18n.t("feeds.form_apple_settings.mapped_feed"), count: 0
    assert_select "a", text: I18n.t("feeds.form_apple_settings.create_feed"), count: 0
  end

  test "prefills a new feed mapped to a public feed's show with Apple Subscriptions defaults" do
    podcast.default_feed.update!(display_episodes_count: 7, audio_format: {f: "mp3", b: 96, c: 1, s: 22050})
    binding = create(:apple_show_feed_binding, feed: feed, apple_show_id: "show-1")

    get new_podcast_feed_url(podcast, feed: {apple_settings: {delivery: binding.id}})

    assert_response :success
    assert_select "input[name='feed[label]'][value='Apple Subscriptions']"
    assert_select "input[name='feed[slug]'][value='#{Apple::DeliveryFeedDefaults::SLUG}']"
    assert_select "input[name='feed[display_episodes_count]'][value='7']"
    assert_select "input[type='checkbox'][name='feed[billboard]'][checked]"
    assert_select "input[type='checkbox'][name='feed[sonic_id]'][checked]"
    assert_select "input[type='checkbox'][name='feed[house]']:not([checked])"
    assert_select "input[type='checkbox'][name='feed[paid]']:not([checked])"
    assert_select "select[name='feed[audio_type]'] option[selected][value='mp3']"
    assert_select "select[name='feed[audio_bitrate]'] option[selected][value='96']"
    assert_select "select[name='feed[audio_channel]'] option[selected][value='1']"
    assert_select "select[name='feed[audio_sample]'] option[selected][value='44100']"
    assert_select "select[name='feed[apple_settings][delivery]'] option[selected][value='#{binding.id}']", text: "#{feed.label} (show-1)"
    assert_select "select[name='feed[apple_settings][delivery]'] option", count: 2
    assert_select "select[name='feed[apple_settings][delivery]'] option[value='own']", count: 0
    assert_select "select[name='feed[apple_settings][connection]']", count: 0
    assert_select "input[name='feed[apple_verify_token]']", count: 1
  end

  test "does not show another podcast's binding mapped from a new feed link" do
    other_feed = create(:feed, podcast: create(:podcast), private: false, label: "Other Podcast Feed")
    other_binding = create(:apple_show_feed_binding, feed: other_feed, apple_show_id: "other-show")

    get new_podcast_feed_url(podcast, feed: {apple_settings: {delivery: other_binding.id}})

    assert_response :success
    assert_select "select[name='feed[apple_settings][delivery]'] option[value='#{other_binding.id}']", count: 0
    assert_select "input[value='other-show']", count: 0
    assert_select "a[href='#{podcast_feed_path(other_feed.podcast, other_feed)}']", count: 0
    refute_includes response.body, "Other Podcast Feed"
  end

  test "does not apply Apple Subscriptions defaults to an ordinary new feed" do
    get new_podcast_feed_url(podcast)

    assert_response :success
    assert_select "input[name='feed[label]'][value='Apple Subscriptions']", count: 0
    assert_select "select[name='feed[apple_settings][delivery]']", count: 0
  end

  test "creates a private feed that delivers through a public feed's show" do
    binding = create(:apple_show_feed_binding, feed: feed, apple_show_id: "show-1")

    assert_difference(["Feed.count", "Apple::DelegatedDeliveryConfig.count"]) do
      post podcast_feeds_url(podcast), params: {
        feed: {label: "Apple Subscriptions", slug: Apple::DeliveryFeedDefaults::SLUG, title: "Apple Subscriptions", private: true, apple_settings: {delivery: binding.id, publish_enabled: "1", sync_blocks_rss: "0"}}
      }
    end

    new_feed = Feed.last
    assert_redirected_to podcast_feed_url(podcast, new_feed)
    assert_predicate new_feed, :private?
    assert_equal binding, new_feed.delegated_delivery_config.show_feed_binding
    assert_predicate new_feed.delegated_delivery_config, :publish_enabled?
    assert_equal [Apple::DelegatedDeliveryConfig::DEFAULT_TOKEN_LABEL], new_feed.tokens.map(&:label)
  end

  test "does not connect without a selected podcast credential" do
    patch podcast_feed_url(podcast, feed), params: {
      feed: {apple_settings: {connection: "show-1"}}
    }

    assert_response :unprocessable_entity
    assert_select '.card-body > .alert-danger[role="alert"]', text: /must be selected for the feed's podcast/
    assert_nil feed.reload.apple_show_feed_binding
  end

  test "keeps connection errors outside the frame that reloads the dropdown" do
    connected_apple_feed
    stub_request(:get, "https://aardvark.prx.org/shows/show-2").to_return(status: 403, body: "{}")

    patch podcast_feed_url(podcast, feed), params: {feed: {apple_settings: {connection: "show-2"}}}

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

    patch podcast_feed_url(podcast, feed), params: {feed: {apple_settings: {connection: "show-2"}}}

    assert_response :unprocessable_entity
    assert_select '.card-body > .alert-danger[role="alert"]', text: "Apple show is already connected to another feed"
    assert_equal "show-1", feed.reload.apple_show_feed_binding.apple_show_id
  end

  test "disconnects a default feed and removes its legacy Apple sync log" do
    default_feed = podcast.default_feed
    binding = create(:apple_show_feed_binding, feed: default_feed)
    sync_log = Apple::SyncLog.log!(feeder_type: :feeds, feeder_id: default_feed.id, external_id: binding.apple_show_id)

    patch podcast_feed_url(podcast, default_feed), params: {feed: {apple_settings: {connection: ""}}}

    assert_redirected_to podcast_feed_url(podcast, default_feed)
    assert_nil default_feed.reload.apple_show_feed_binding
    assert_nil default_feed.apple_sync_log
    refute SyncLog.exists?(sync_log.id)
    config = Apple::DelegatedDeliveryConfig.new(feed: private_feed)
    assert_nil config.legacy_apple_show_id
  end

  test "does not disconnect a binding used by delegated delivery" do
    key = create(:apple_key, account_id: podcast.account_id)
    podcast.update!(apple_key: key)
    binding = create(:apple_show_feed_binding, feed: feed)
    create(:delegated_delivery_config, feed: private_feed, key: key, show_feed_binding: binding)

    patch podcast_feed_url(podcast, feed), params: {feed: {apple_settings: {connection: ""}}}

    assert_response :unprocessable_entity
    assert_predicate binding.reload, :persisted?
    assert_not_requested :get, "https://aardvark.prx.org/shows"
  end

  test "does not make a connected public feed private" do
    connected_apple_feed

    patch podcast_feed_url(podcast, feed), params: {feed: {
      private: "1",
      feed_tokens_attributes: {"0" => {label: "apple", token: "apple-token"}},
      apple_settings: {delivery: ""}
    }}

    assert_response :unprocessable_entity
    assert_select ".invalid-feedback", text: /cannot be enabled while this feed is connected to an apple show/i
    refute feed.reload.private?
    assert_empty feed.tokens
    assert_equal "show-1", feed.apple_show_feed_binding.apple_show_id
  end

  test "renders the connection and error when delegated delivery prevents deletion" do
    connected_apple_feed
    binding = feed.apple_show_feed_binding
    config = create(:delegated_delivery_config, feed: private_feed, key: podcast.apple_key, show_feed_binding: binding)

    delete podcast_feed_url(podcast, feed)

    assert_response :unprocessable_entity
    assert_includes response.body, "Cannot delete a feed while delegated delivery uses its Apple connection"
    assert_select 'select[name="feed[apple_settings][connection]"] option[selected][value="show-1"]'
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
      feed: {apple_settings: {connection: "new-show"}}
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

    patch podcast_feed_url(podcast, default_feed), params: {feed: {apple_settings: {connection: "new-show"}}}

    assert_redirected_to podcast_feed_url(podcast, default_feed)
    assert_equal "new-show", default_feed.reload.apple_sync_log.external_id
    assert_nil default_feed.delegated_delivery_config
  end

  test "updates the connection when the private feed is invalid" do
    default_feed = podcast.default_feed
    key = create(:apple_key, account_id: podcast.account_id)
    podcast.update!(apple_key: key)
    binding = create(:apple_show_feed_binding, feed: default_feed, apple_show_id: "old-show")
    config = create(:delegated_delivery_config, feed: private_feed, key: key, show_feed_binding: binding)
    sync_log = Apple::SyncLog.log!(feeder_id: default_feed.id, feeder_type: :feeds, external_id: "old-show")
    private_feed.update_column(:file_name, "")
    refute private_feed.reload.valid?
    assert private_feed.errors[:file_name].any?
    body = {data: {id: "new-show", type: "shows", attributes: {title: "New show"}}}.to_json
    stub_request(:get, "https://aardvark.prx.org/shows/new-show").to_return(status: 200, body: body)

    patch podcast_feed_url(podcast, default_feed), params: {
      feed: {title: "Changed title", apple_settings: {connection: "new-show"}}
    }

    assert_redirected_to podcast_feed_url(podcast, default_feed)
    assert_equal "Changed title", default_feed.reload.title
    assert_equal "new-show", binding.reload.apple_show_id
    assert_equal "new-show", private_feed.reload.apple_show_id
    assert_equal "new-show", sync_log.reload.external_id
    assert_equal key, config.reload.key
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
