require "test_helper"

describe Api::Auth::EpisodesController do
  let(:account_id) { 123 }
  let(:podcast) { create(:podcast, prx_account_uri: "/api/v1/accounts/#{account_id}") }
  let(:member_token) do
    StubToken.new(account_id,
      ["member feeder:read-private feeder:podcast-edit feeder:podcast-create feeder:episode feeder:episode-draft"])
  end
  let(:limited_token) { StubToken.new(account_id, ["member feeder:read-private"]) }
  let(:admin_token) do
    StubToken.new(account_id,
      ["admin feeder:read-private feeder:podcast-edit feeder:podcast-create feeder:episode feeder:episode-draft"])
  end
  let(:episode) { create(:episode, podcast: podcast) }

  let(:different_podcast) { create(:podcast, prx_account_uri: "/api/v1/accounts/#{account_id}", path: "diff") }
  let(:episode_different_podcast) { create(:episode, podcast: different_podcast) }

  let(:episode_unpublished) { create(:episode, podcast: podcast, published_at: nil) }
  let(:episode_scheduled) { create(:episode_with_media, podcast: podcast, published_at: Time.now + 1.hour) }
  let(:episode_deleted) { create(:episode, deleted_at: Time.now, podcast: podcast) }
  let(:episode_hash) do
    {
      title: "title",
      releasedAt: "2020-03-12T18:02:03.000Z",
      prxUri: "/api/v1/stories/123",
      media: [
        {href: "https://s3.amazonaws.com/prx-testing/test/audio1.mp3"},
        {href: "https://s3.amazonaws.com/prx-testing/test/audio2.mp3"},
        {href: "https://s3.amazonaws.com/prx-testing/test/audio3.mp3"}
      ]
    }
  end

  before do
    class << @controller; attr_accessor :prx_auth_token; end
    @controller.prx_auth_token = member_token
    @request.env["CONTENT_TYPE"] = "application/json"
  end

  it "should show the unpublished episode" do
    refute_nil episode_unpublished.id
    assert_nil episode_unpublished.published_at
    get(:show, params: {api_version: "v1", format: "json", id: episode_unpublished.guid})
    assert_response :success
  end

  it "should show" do
    refute_nil episode.id
    get(:show, params: {api_version: "v1", format: "json", id: episode.guid})
    assert_response :success
  end

  it "should return resource gone for deleted resource" do
    refute_nil episode_deleted.id
    get(:show, params: {api_version: "v1", format: "json", id: episode_deleted.guid})
    assert_response 410
  end

  it "should return not found for unknown resource" do
    refute_nil episode_deleted.id
    get(:show, params: {api_version: "v1", format: "json", id: "thisismadeup"})
    assert_response 404
  end

  it "should list" do
    refute_nil episode.id
    refute_nil episode_unpublished.id
    assert_nil episode_unpublished.published_at
    refute_nil episode_deleted.id
    get(:index, params: {api_version: "v1", format: "json"})
    assert_response :success
    list = JSON.parse(response.body)
    ids = list.dig("_embedded", "prx:items").map { |i| i["id"] }
    assert_includes ids, episode.guid
    assert_includes ids, episode_unpublished.guid
    refute_includes ids, episode_deleted.guid
  end

  it "should list for podcast" do
    refute_nil episode.id
    refute_nil podcast.id
    refute_nil episode_different_podcast.id
    get(:index, params: {api_version: "v1", format: "json", podcast_id: podcast.id})
    assert_response :success
    body = JSON.parse(response.body)
    ids = body["_embedded"]["prx:items"].map { |s| s["id"] }
    assert_equal ids.count, 1
    refute_includes ids, episode_different_podcast.guid
  end

  describe "with a valid token" do
    let(:account_id) { 123 }
    let(:podcast) { create(:podcast, prx_account_uri: "/api/v1/accounts/#{account_id}") }
    let(:episode_redirect) { create(:episode, podcast: podcast, published_at: nil) }
    let(:episode_update) { create(:episode, podcast: podcast, published_at: nil) }

    before do
      class << @controller; attr_accessor :prx_auth_token; end
      @controller.prx_auth_token = member_token
      @request.env["CONTENT_TYPE"] = "application/json"
    end

    it "can create a new episode" do
      @controller.stub(:publish, true) do
        @controller.stub(:process_media, true) do
          post(:create, body: episode_hash.to_json, as: :json,
            params: {api_version: "v1", format: "json", podcast_id: podcast.id})
        end
      end
      assert_response :success
      id = JSON.parse(response.body)["id"]
      new_episode = Episode.find_by_guid(id)
      assert_equal new_episode.released_at, Time.parse(episode_hash[:releasedAt])
      assert_equal new_episode.prx_uri, "/api/v1/stories/123"
      assert_equal new_episode.contents.count, 3
      c = new_episode.contents.first
      assert_equal c.original_url, "https://s3.amazonaws.com/prx-testing/test/audio1.mp3"
    end

    it "can update audio on an episode" do
      update_hash = {media: [{href: "https://s3.amazonaws.com/prx-testing/test/change1.mp3"}]}

      assert_equal episode_update.contents.size, 0

      @controller.stub(:publish, true) do
        @controller.stub(:process_media, true) do
          put(:update, body: update_hash.to_json, as: :json,
            params: {id: episode_update.guid, api_version: "v1", format: "json"})
        end
      end
      assert_response :success

      assert_equal episode_update.reload.contents.size, 1

      # updating with a dupe should not insert it
      @controller.stub(:publish, true) do
        @controller.stub(:process_media, true) do
          put(:update, body: update_hash.to_json, as: :json,
            params: {id: episode_update.guid, api_version: "v1", format: "json"})
        end
      end
      assert_response :success

      assert_equal episode_update.reload.contents.with_deleted.size, 1
      assert_equal episode_update.contents.with_deleted.first.position, 1
    end

    it "can add uncut to an episode" do
      update_hash = {
        uncut: {
          href: "https://s3.amazonaws.com/prx-testing/test/change1.mp3"
        }
      }

      assert_equal episode_update.contents.size, 0
      assert_nil episode_update.uncut
      assert_nil episode_update.medium

      @controller.stub(:process_media, true) do
        put(:update, body: update_hash.to_json, as: :json,
          params: {id: episode_update.guid, api_version: "v1", format: "json"})
      end
      assert_response :success

      episode_update.reload

      contents = episode_update.contents
      assert_equal contents.size, 0

      uncut = episode_update.uncut
      assert_not_nil uncut
      assert_equal "uncut", episode_update.medium

      # put to update without setting should not delete uncut
      @controller.stub(:process_media, true) do
        put(:update, body: {title: "still uncut"}.to_json, as: :json,
          params: {id: episode_update.guid, api_version: "v1", format: "json"})
      end
      assert_response :success

      episode_update.reload

      assert_not_nil episode_update.uncut
      assert_equal uncut.id, episode_update.uncut.id

      # updating segmentation should update it
      update_hash = {
        segment_count: 2,
        uncut: {
          href: "https://s3.amazonaws.com/prx-testing/test/change1.mp3",
          segmentation: [[nil, 10]]
        }
      }
      @controller.stub(:process_media, true) do
        put(:update, body: update_hash.to_json, as: :json,
          params: {id: episode_update.guid, api_version: "v1", format: "json"})
      end
      assert_response :success

      episode_update.reload

      assert_equal uncut.id, episode_update.uncut.id
      assert_equal [[nil, 10]], episode_update.uncut.segmentation

      # updating segmentation with no href should update not replace
      update_hash = {
        segment_count: 2,
        uncut: {
          segmentation: [[nil, 15]]
        }
      }
      @controller.stub(:process_media, true) do
        put(:update, body: update_hash.to_json, as: :json,
          params: {id: episode_update.guid, api_version: "v1", format: "json"})
      end
      assert_response :success

      episode_update.reload

      assert_equal uncut.id, episode_update.uncut.id
      assert_equal [[nil, 15]], episode_update.uncut.segmentation

      # updating with a nil should delete it
      update_hash = {uncut: nil}
      @controller.stub(:process_media, true) do
        put(:update, body: update_hash.to_json, as: :json,
          params: {id: episode_update.guid, api_version: "v1", format: "json"})
      end
      assert_response :success

      episode_update.reload

      assert_nil episode_update.uncut
      assert_nil episode_update.medium
    end
  end

  describe "with wildcard token" do
    let(:member_token) { StubToken.new("*", ["feeder:read-private"]) }
    let(:other_podcast) { create(:podcast, prx_account_uri: "/api/v1/accounts/#{account_id + 1}", path: "foo") }
    let(:other_unpublished_episode) { create(:episode, podcast: other_podcast, published_at: nil) }

    it "includes all episodes (including unpublished and deleted) when querying updated since" do
      guids = [episode_unpublished.guid, other_unpublished_episode.guid, episode_deleted.guid]
      get(:index, params: {api_version: "v1", format: "json", since: "2020-01-01"})
      assert_response :success
      list = JSON.parse(response.body)
      ids = list.dig("_embedded", "prx:items").map { |i| i["id"] }
      guids.each do |guid|
        assert_includes ids, guid
      end
    end

    it "cannot create a new episode" do
      post(:create, body: episode_hash.to_json, as: :json,
        params: {api_version: "v1", format: "json", podcast_id: podcast.id})
      assert_response :unauthorized
    end
  end

  describe "with admin token" do
    before do
      ENV["API_ADMIN_TOKENS"] = "ABCD,EFGH"
      @request.env["HTTP_AUTHORIZATION"] = "Token EFGH"
      @controller.prx_auth_token = nil
    end

    it "returns unpublished episodes with media hrefs" do
      get(:show, params: {api_version: "v1", format: "json", id: episode_scheduled.guid})
      assert_response :success

      json = JSON.parse(response.body)
      assert_operator Time.parse(json["publishedAt"]), :>=, Time.now
      assert_equal 1, json["media"].count
      assert_equal episode_scheduled.contents[0].url, json["media"][0]["href"]
    end
  end
end
