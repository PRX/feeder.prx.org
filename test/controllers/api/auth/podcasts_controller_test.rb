require "test_helper"

describe Api::Auth::PodcastsController do
  let(:account_id) { 123 }
  let(:podcast) { create(:podcast, prx_account_uri: "/api/v1/accounts/#{account_id}", published_at: nil) }
  let(:published_podcast) { create(:podcast, prx_account_uri: "/api/v1/accounts/#{account_id}", path: "pod2") }
  let(:other_account_podcast) { create(:podcast, prx_account_uri: "/api/v1/accounts/9876", path: "pod3") }
  let(:deleted_podcast) do
    create(:podcast, prx_account_uri: "/api/v1/accounts/#{account_id}", path: "pod4", deleted_at: Time.now)
  end
  let(:token) { StubToken.new(account_id, ["feeder:read-private"]) }

  before do
    class << @controller; attr_accessor :prx_auth_token; end
    @controller.prx_auth_token = token
    @request.env["CONTENT_TYPE"] = "application/json"
  end

  it "should show the unpublished podcast" do
    refute_nil podcast.id
    assert_nil podcast.published_at
    get(:show, params: {api_version: "v1", format: "json", id: podcast.id})
    assert_response :success
  end

  it "should not show unowned podcast" do
    get(:show, params: {api_version: "v1", format: "json", id: other_account_podcast.id})
    assert_response :not_found
  end

  it "should only index account podcasts" do
    podcast && published_podcast && other_account_podcast && deleted_podcast
    get(:index, params: {api_version: "v1"})
    assert_response :success
    assert_not_nil assigns[:podcasts]
    assert_includes assigns[:podcasts], podcast
    assert_includes assigns[:podcasts], published_podcast
    refute_includes assigns[:podcasts], other_account_podcast
    refute_includes assigns[:podcasts], deleted_podcast
  end

  describe "with wildcard token" do
    let(:token) { StubToken.new("*", ["read-private"]) }

    it "includes all podcasts" do
      podcast && published_podcast && other_account_podcast && deleted_podcast
      get(:index, params: {api_version: "v1"})
      assert_response :success
      assert_not_nil assigns[:podcasts]
      assert_includes assigns[:podcasts], podcast
      assert_includes assigns[:podcasts], published_podcast
      assert_includes assigns[:podcasts], other_account_podcast
      assert_includes assigns[:podcasts], deleted_podcast
    end
  end
end
