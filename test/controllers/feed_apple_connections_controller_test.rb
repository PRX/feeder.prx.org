require "test_helper"

class FeedAppleConnectionsControllerTest < ActionDispatch::IntegrationTest
  let(:podcast) { create(:podcast, prx_account_uri: "/api/v1/accounts/123") }
  let(:feed) { create(:feed, podcast: podcast, private: false) }
  let(:locked_feed) { create(:feed, podcast: podcast, private: false, edit_locked: true) }
  let(:private_feed) { create(:private_feed, podcast: podcast) }

  let(:connected_apple_feed) do
    podcast.update!(apple_key: create(:apple_key, account_id: podcast.account_id))
    create(:apple_show_feed_binding, feed: feed, apple_show_id: "show-1")
    feed
  end

  setup_current_user { build(:user, account_id: 123) }

  test "authorizes the lookup before calling Apple" do
    connected_apple_feed
    podcast.update!(prx_account_uri: "/api/v1/accounts/456", apple_key: nil)

    get podcast_feed_apple_connection_url(podcast, feed)

    assert_response :forbidden
    assert_not_requested :get, "https://aardvark.prx.org/shows"
  end

  test "requires the feed to belong to the requested podcast" do
    other_podcast = create(:podcast)

    assert_raises ActiveRecord::RecordNotFound do
      get podcast_feed_apple_connection_url(other_podcast, feed)
    end
  end

  test "does not look up shows for private feeds" do
    get podcast_feed_apple_connection_url(podcast, private_feed)

    assert_response :not_found
    assert_not_requested :get, "https://aardvark.prx.org/shows"
  end

  test "renders without an Apple request when no credential is selected" do
    get podcast_feed_apple_connection_url(podcast, feed), headers: {"Turbo-Frame" => "apple_connection_feed_#{feed.id}"}

    assert_response :success
    assert_select "turbo-frame#apple_connection_feed_#{feed.id}"
    assert_select 'select[name="feed[apple_connection]"]:not([disabled])'
    assert_select "form", count: 0
    assert_select 'input[name="feed[apple_connection]"]', count: 0
    assert_not_requested :get, "https://aardvark.prx.org/shows"
  end

  test "keeps the asynchronously loaded dropdown disabled for locked feeds" do
    get podcast_feed_apple_connection_url(podcast, locked_feed)

    assert_response :success
    assert_select 'select[name="feed[apple_connection]"][disabled]'
  end

  test "preserves a submitted show and the saved confirmation baseline after lookup failure" do
    connected_apple_feed
    stub_request(:get, "https://aardvark.prx.org/shows").to_return(status: 503, body: "{}")

    get podcast_feed_apple_connection_url(podcast, feed), params: {selection: "show-2"}

    assert_response :success
    assert_select 'select[name="feed[apple_connection]"][data-value-was="show-1"].is-changed' do
      assert_select 'option[selected][value="show-2"]'
      assert_select 'option[value="show-1"]'
    end
    assert_equal "show-1", feed.reload.apple_show_feed_binding.apple_show_id
  end

  test "warns and preserves the connected show when Apple rejects the lookup" do
    apple_feed = connected_apple_feed
    stub_request(:get, "https://aardvark.prx.org/shows").to_return(status: 401, body: "Invalid credentials")

    get podcast_feed_apple_connection_url(podcast, apple_feed)

    assert_response :success
    assert_select '.alert-danger[role="alert"]', text: I18n.t("feeds.form_apple_connection.show_lookup_failed")
    assert_select 'select[name="feed[apple_connection]"] option[selected][value="show-1"]', text: "show-1"
  end

  test "warns and preserves the connected show when Apple credentials cannot be decrypted" do
    apple_feed = connected_apple_feed
    failure = -> { raise ActiveRecord::Encryption::Errors::Decryption }
    Apple::Key.stub_any_instance(:key_pem, failure) do
      get podcast_feed_apple_connection_url(podcast, apple_feed)
    end

    assert_response :success
    assert_select '.alert-danger[role="alert"]', text: I18n.t("feeds.form_apple_connection.show_lookup_failed")
    assert_select 'select[name="feed[apple_connection]"] option[selected][value="show-1"]', text: "show-1"
  end

  test "leaves the show unselected when lookup fails without a connection" do
    podcast.update!(apple_key: create(:apple_key, account_id: podcast.account_id))
    stub_request(:get, "https://aardvark.prx.org/shows").to_return(status: 401, body: "Invalid credentials")

    get podcast_feed_apple_connection_url(podcast, feed)

    assert_response :success
    assert_select '.alert-danger[role="alert"]', text: I18n.t("feeds.form_apple_connection.show_lookup_failed")
    assert_select 'select[name="feed[apple_connection]"] option:not([value=""])', count: 0
  end

  test "does not warn when Apple returns no shows" do
    apple_feed = connected_apple_feed
    stub_request(:get, "https://aardvark.prx.org/shows").to_return(status: 200, body: {data: [], links: {}}.to_json)

    get podcast_feed_apple_connection_url(podcast, apple_feed)

    assert_response :success
    assert_select '.alert-danger[role="alert"]', text: I18n.t("feeds.form_apple_connection.show_lookup_failed"), count: 0
    assert_select 'select[name="feed[apple_connection]"] option[selected][value="show-1"]'
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
      get podcast_feed_apple_connection_url(podcast, feed)
    end

    assert_response :success
    assert_select "select[name='feed[apple_connection]'] option[value='show-1']", text: "Selected show — show-1"
  end

  test "requires confirmation when replacing a connection used by delegated delivery" do
    connected_apple_feed
    create(:delegated_delivery_config, feed: private_feed, key: podcast.apple_key, show_feed_binding: feed.apple_show_feed_binding)

    Apple::ShowFeedBinding.stub(:connection_options, []) do
      get podcast_feed_apple_connection_url(podcast, feed)
    end

    assert_response :success
    assert_select 'select[name="feed[apple_connection]"][data-confirm-field-target="field"]' do |fields|
      assert_equal I18n.t("feeds.form_apple_connection.confirm_replace"), fields.first["data-confirm-with"]
      assert_equal I18n.t("feeds.form_apple_connection.confirm_remove"), fields.first["data-confirm-delete"]
    end
  end
end
