require "test_helper"

describe Api::Auth::FeedsController do
  let(:account_id) { 123 }
  let(:podcast) { create(:podcast, prx_account_uri: "/api/v1/accounts/#{account_id}") }
  let(:feed) { create(:feed, podcast: podcast, slug: "test-slug") }
  let(:token) { StubToken.new(account_id, "feeder:read-private feeder:podcast-edit") }
  let(:bad_token) { StubToken.new(account_id + 100, "feeder:read-private feeder:podcast-edit") }

  let(:feed_hash) do
    {
      slug: "test-slug",
      title: "test feed"
    }
  end

  describe "with a valid token" do
    around do |test|
      class << @controller; attr_accessor :prx_auth_token; end
      @controller.prx_auth_token = token
      @request.env["CONTENT_TYPE"] = "application/json"
      @controller.stub(:publish, true) do
        test.call
      end
    end

    it "can create a new feed" do
      post(:create, body: feed_hash.to_json, as: :json,
        params: {api_version: "v1", format: "json", podcast_id: podcast.id})
      assert_response :success
      id = JSON.parse(response.body)["id"]
      new_feed = Feed.find(id)
      _(new_feed.slug).must_equal "test-slug"
    end

    it "can update a feed" do
      fua = feed.updated_at
      update_hash = {title: "new title", slug: "somesluggy1"}

      put(:update, body: update_hash.to_json, as: :json,
        params: {api_version: "v1", format: "json", podcast_id: feed.podcast_id, id: feed.id})
      assert_response :success

      _(feed.reload.updated_at).must_be :>, fua
      _(feed.title).must_equal "new title"
    end

    describe "feed tokens" do
      before do
        feed.tokens.create!(label: "something", token: "tok1")
        feed.tokens.create!(label: "something2", token: "tok2")
      end

      it "can create a new feed with tokens" do
        token_hash = {
          slug: "token-slug",
          title: "token feed",
          tokens: [
            {token: "tok3", label: "tok3", expires: "2023-02-01"},
            {token: "tok4", label: "tok4"}
          ]
        }

        post(:create, body: token_hash.to_json, as: :json,
          params: {api_version: "v1", format: "json", podcast_id: podcast.id})

        assert_response :success
        id = JSON.parse(response.body)["id"]
        new_feed = Feed.find(id)
        _(new_feed.reload.tokens.count).must_equal 2
      end

      it "can update nested tokens" do
        update_tok1 = {token: "tok1", label: "else", expires: "2023-02-01"}
        create_tok3 = {token: "tok3", label: "tok3"}
        update_hash = {tokens: [update_tok1, create_tok3]}

        put(:update, body: update_hash.to_json, as: :json,
          params: {api_version: "v1", format: "json", podcast_id: feed.podcast_id, id: feed.id})

        assert_response :success
        _(feed.reload.tokens.count).must_equal 2
      end

      it "can delete nested tokens" do
        update_hash = {tokens: []}

        put(:update, body: update_hash.to_json, as: :json,
          params: {api_version: "v1", format: "json", podcast_id: feed.podcast_id, id: feed.id})

        assert_response :success
        _(feed.reload.tokens.count).must_equal 0
      end
    end

    describe "feed images" do
      let(:url1) { "http://www.prx.org/fakeimageurl1.jpg" }
      let(:url2) { "http://www.prx.org/fakeimageurl2.jpg" }

      it "appends feed and itunes images" do
        _(feed.feed_images.count).must_equal 0
        fua = feed.updated_at

        update_hash = {feedImage: {href: url1, caption: "d1"}}
        put(:update, body: update_hash.to_json, as: :json,
          params: {api_version: "v1", format: "json", podcast_id: feed.podcast_id, id: feed.id})
        assert_response :success

        _(feed.reload.updated_at).must_be :>, fua
        _(feed.feed_images.count).must_equal 1
        _(feed.feed_images.first.caption).must_equal "d1"
        _(feed.itunes_images.count).must_equal 0
        fua = feed.updated_at

        update_hash = {feedImage: {href: url2, caption: "d2"}, itunesImage: {href: url1, caption: "d3"}}
        put(:update, body: update_hash.to_json, as: :json,
          params: {api_version: "v1", format: "json", podcast_id: feed.podcast_id, id: feed.id})
        assert_response :success
        put(:update, body: update_hash.to_json, as: :json,
          params: {api_version: "v1", format: "json", podcast_id: feed.podcast_id, id: feed.id})
        assert_response :success

        _(feed.reload.updated_at).must_be :>, fua
        _(feed.feed_images.with_deleted.count).must_equal 2
        _(feed.feed_images.with_deleted.first.caption).must_equal "d2"
        _(feed.feed_images.with_deleted.last.caption).must_equal "d1"
        _(feed.itunes_images.with_deleted.count).must_equal 1
        _(feed.itunes_images.with_deleted.last.caption).must_equal "d3"
      end
    end

    it "ignores updating invalid overrides" do
      fua = feed.updated_at
      update_hash = {title: "new title2", slug: "somesluggy2", display_episodes_count: 1}

      put(:update, body: update_hash.to_json, as: :json,
        params: {api_version: "v1", format: "json", podcast_id: feed.podcast_id, id: feed.id})
      assert_response :success

      feed.reload
      _(feed.updated_at).must_be :>, fua
      _(feed.slug).must_equal "somesluggy2"
    end

    it "rejects update for unauthorizd token" do
      @controller.prx_auth_token = bad_token
      update_hash = {title: "new title3", slug: "somesluggy3", display_episodes_count: 1}

      put(:update, body: update_hash.to_json, as: :json,
        params: {api_version: "v1", format: "json", podcast_id: feed.podcast_id, id: feed.id})
      assert_response :not_found
    end

    it "rejects show for unauthorized token" do
      @controller.prx_auth_token = bad_token

      get(:show, params: {api_version: "v1", format: "json", podcast_id: feed.podcast_id, id: feed.id})
      assert_response :not_found
    end
  end

  describe "without a token" do
    it "should not show" do
      get(:show, params: {api_version: "v1", format: "json", podcast_id: feed.podcast_id, id: feed.id})
      assert_response :unauthorized
    end

    it "should not list" do
      get(:index, params: {api_version: "v1", format: "json", podcast_id: feed.podcast_id})
      assert_response :unauthorized
    end
  end
end
