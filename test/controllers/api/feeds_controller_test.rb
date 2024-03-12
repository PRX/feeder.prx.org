require "test_helper"

describe Api::FeedsController do
  let(:account_id) { 123 }
  let(:podcast) { create(:podcast, prx_account_uri: "/api/v1/accounts/#{account_id}") }
  let(:f1) { podcast.default_feed }
  let(:f2) { create(:public_feed, podcast: podcast, slug: "slug-2", audio_format: nil, include_zones: []) }
  let(:f3) { create(:private_feed, podcast: podcast, slug: "slug-3", private: true, episode_offset_seconds: 99) }

  describe "with a valid token" do
    let(:token) { StubToken.new(account_id, ["feeder:read-private"]) }

    before do
      class << @controller; attr_accessor :prx_auth_token; end
      @controller.prx_auth_token = token
      @request.env["CONTENT_TYPE"] = "application/json"
    end

    it "rejects auth tokens" do
      get(:index, params: {api_version: "v1", format: "json"})
      assert_response :unauthorized
    end
  end

  describe "with no auth" do
    it "returns unauthorized" do
      get(:index, params: {api_version: "v1", format: "json"})
      assert_response :unauthorized
    end
  end

  describe "with an invalid admin token" do
    before do
      ENV["API_ADMIN_TOKENS"] = "ABCD"
      @request.env["HTTP_AUTHORIZATION"] = "Token EFGH"
    end

    it "returns unauthorized" do
      get(:index, params: {api_version: "v1", format: "json"})
      assert_response :unauthorized
    end
  end

  describe "with a valid admin token" do
    before do
      ENV["API_ADMIN_TOKENS"] = "ABCD,EFGH"
      @request.env["HTTP_AUTHORIZATION"] = "Token EFGH"

      assert f1.persisted?
      assert f2.persisted?
      assert f3.persisted?
    end

    it "returns feed settings" do
      get(:index, params: {api_version: "v1", format: "json"})
      assert_response :success

      json = JSON.parse(response.body)
      assert json.key?(podcast.id.to_s)
      assert_equal ["slug-2", "slug-3"], json[podcast.id.to_s]["feeds"].keys.sort

      json1 = json[podcast.id.to_s]["defaultFeed"]
      json2 = json[podcast.id.to_s]["feeds"]["slug-2"]
      json3 = json[podcast.id.to_s]["feeds"]["slug-3"]

      assert_equal false, json1["private"]
      assert_nil json1["includeZones"]
      assert_equal f1.audio_format, json1["audioFormat"]
      assert_nil json1["episodeOffsetSeconds"]

      assert_equal false, json2["private"]
      assert_equal [], json2["includeZones"]
      assert_nil json2["audioFormat"]
      assert_nil json2["episodeOffsetSeconds"]

      assert_equal true, json3["private"]
      assert_nil json3["includeZones"]
      assert_equal f3.audio_format, json3["audioFormat"]
      assert_equal 99, json3["episodeOffsetSeconds"]

      assert_equal 1, json3["tokens"].count
      assert_equal f3.tokens[0].label, json3["tokens"][0]["label"]
      assert_equal f3.tokens[0].token, json3["tokens"][0]["token"]
      assert_nil json3["tokens"][0]["expiresAt"]
    end

    it "does not return podcasts with default settings" do
      Podcast.stub_any_instance(:default_feed_settings?, true) do
        get(:index, params: {api_version: "v1", format: "json"})
        assert_response :success

        json = JSON.parse(response.body)
        refute json.key?(podcast.id.to_s)
      end
    end
  end
end
