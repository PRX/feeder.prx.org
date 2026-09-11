require "test_helper"

module Apple
  describe ShowFeedBinding do
    it "does not store an Apple key" do
      refute_includes ShowFeedBinding.column_names, "apple_key_id"
    end

    it "has one config" do
      podcast = create(:podcast)
      binding = create(:apple_show_feed_binding, feed: create(:public_feed, podcast: podcast))
      key = create(:apple_key, account_id: podcast.account_id)
      config = create(
        :delegated_delivery_config,
        feed: create(:private_feed, podcast: podcast),
        key: key,
        show_feed_binding: binding
      )

      assert_equal config, binding.reload.config
    end

    describe "validations" do
      it "requires an apple show id" do
        binding = build(:apple_show_feed_binding, apple_show_id: nil)

        refute binding.valid?
        assert_includes binding.errors[:apple_show_id], "Can't be blank"
      end

      it "requires a public feed" do
        private_feed = create(:private_feed, podcast: create(:podcast))
        binding = build(:apple_show_feed_binding, feed: private_feed)

        refute binding.valid?
        assert_includes binding.errors[:feed], "must be a public feed"
      end

      it "allows only one binding per feed" do
        feed = create(:public_feed, podcast: create(:podcast))
        create(:apple_show_feed_binding, feed: feed)

        binding = build(:apple_show_feed_binding, feed: feed)

        refute binding.valid?
        assert_includes binding.errors[:feed_id], "has already been taken"
      end
    end

    describe ".active" do
      it "excludes bindings whose feeds are soft deleted" do
        binding = create(:apple_show_feed_binding)
        active_binding = create(:apple_show_feed_binding)

        Feed.where(id: binding.feed_id).update_all(deleted_at: Time.current)

        assert_includes ShowFeedBinding.active.to_a, active_binding
        refute_includes ShowFeedBinding.active.to_a, binding
      end
    end

    describe ".connect_existing" do
      it "verifies show access before creating a binding" do
        key = create(:apple_key, account_id: 123)
        podcast = create(:podcast, prx_account_uri: "/api/v1/accounts/123", apple_key: key)
        feed = create(:public_feed, podcast: podcast)
        body = {data: {id: "show-1", type: "shows", attributes: {title: "A show"}}}.to_json
        stub_request(:get, "https://aardvark.prx.org/shows/show-1").to_return(status: 200, body: body)

        binding = ShowFeedBinding.connect_existing(feed: feed, apple_show_id: "show-1")

        assert_predicate binding, :persisted?
        assert_equal key, feed.podcast.reload.apple_key
      end

      it "does not create a binding when the show is unreadable" do
        key = create(:apple_key, account_id: 123)
        podcast = create(:podcast, prx_account_uri: "/api/v1/accounts/123", apple_key: key)
        feed = create(:public_feed, podcast: podcast)
        stub_request(:get, "https://aardvark.prx.org/shows/missing").to_return(status: 404, body: "{}")

        assert_no_difference "ShowFeedBinding.count" do
          binding = ShowFeedBinding.connect_existing(feed: feed, apple_show_id: "missing")
          refute_predicate binding, :persisted?
          assert_predicate binding.errors[:apple_show_id], :present?
        end
        assert_equal key, feed.podcast.reload.apple_key
      end

      it "requires the podcast to have a selected key" do
        feed = create(:public_feed, podcast: create(:podcast, prx_account_uri: "/api/v1/accounts/123"))

        binding = ShowFeedBinding.connect_existing(feed: feed, apple_show_id: "show-1")

        refute_predicate binding, :persisted?
        assert_includes binding.errors[:apple_key], "must be selected for the feed's podcast"
      end

      it "rejects a selected key from another PRX account" do
        podcast = create(:podcast, prx_account_uri: "/api/v1/accounts/123")
        key = create(:apple_key, account_id: 456)
        podcast.update_column(:apple_key_id, key.id)
        feed = create(:public_feed, podcast: podcast)

        binding = ShowFeedBinding.connect_existing(feed: feed, apple_show_id: "show-1")

        refute_predicate binding, :persisted?
        assert_includes binding.errors[:apple_key], "must belong to the feed's PRX account"
      end
    end

    describe ".connection_options" do
      it "uses show ids as values for non-archived shows" do
        key = create(:apple_key, key_id: "credential12")
        body = {
          data: [
            {id: "show-1", attributes: {title: "Shared", publishingState: "PUBLISHED"}},
            {id: "show-2", attributes: {title: "Old", publishingState: "ARCHIVED"}}
          ],
          links: {}
        }.to_json
        stub_request(:get, "https://aardvark.prx.org/shows").to_return(status: 200, body: body)

        options = ShowFeedBinding.connection_options(key)

        assert_equal ["show-1"], options.map(&:value)
        assert_equal "Shared — show-1", options.first.label
      end

      it "returns no options without a selected key" do
        assert_empty ShowFeedBinding.connection_options(nil)
      end
    end
  end
end
