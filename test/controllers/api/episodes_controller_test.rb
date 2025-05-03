require "test_helper"

describe Api::EpisodesController do
  let(:episode) { create(:episode) }
  let(:podcast) { episode.podcast }
  let(:episode_deleted) { create(:episode, deleted_at: Time.now, podcast: podcast) }
  let(:episode_unpublished) { create(:episode, published_at: nil, podcast: podcast) }
  let(:episode_prepublished) { create(:episode, published_at: (Time.now + 1.week), podcast: podcast) }

  let(:episode_hash) do
    {
      title: "title",
      prxUri: "/api/v1/stories/123",
      media: [
        {href: "https://s3.amazonaws.com/prx-testing/test/audio1.mp3"},
        {href: "https://s3.amazonaws.com/prx-testing/test/audio2.mp3"},
        {href: "https://s3.amazonaws.com/prx-testing/test/audio3.mp3"}
      ]
    }
  end

  it "should show" do
    refute_nil episode.id
    get(:show, params: {api_version: "v1", format: "json", id: episode.guid})
    assert_response :success
  end

  it "should show by item guid" do
    refute_nil episode.id

    get(:show, params: {api_version: "v1", format: "json", id: episode.item_guid, guid_resource: true})
    assert_response :success

    get(:show, params: {api_version: "v1", format: "json", id: episode.guid, guid_resource: true})
    assert_response 404
  end

  it "should return resource gone for deleted resource" do
    refute_nil episode_deleted.id
    get(:show, params: {api_version: "v1", format: "json", id: episode_deleted.guid})
    assert_response 410
  end

  it "should return resource unknown for unpublished resource" do
    refute_nil episode_unpublished.id
    get(:show, params: {api_version: "v1", format: "json", id: episode_unpublished.guid})
    assert_response 404
  end

  it "should return not found for unknown resource" do
    refute_nil episode_deleted.id
    get(:show, params: {api_version: "v1", format: "json", id: "thisismadeup"})
    assert_response 404
  end

  it "should return not found resources not in the default feed" do
    episode.update(feeds: [])
    get(:show, params: {api_version: "v1", format: "json", id: episode.guid})
    assert_response 404
  end

  it "should list" do
    refute_nil episode.id
    refute_nil episode_deleted.id
    get(:index, params: {api_version: "v1", format: "json"})
    assert_response :success
    guids = JSON.parse(response.body)["_embedded"]["prx:items"].map { |p| p["id"] }
    assert_includes guids, episode.guid
    refute_includes guids, episode_deleted.guid
  end

  it "should not list future published" do
    refute_nil episode_unpublished.id
    refute_nil episode_prepublished.id
    refute_nil episode.id
    get(:index, params: {api_version: "v1", format: "json"})
    assert_response :success
    list = JSON.parse(response.body)
    ids = list.dig("_embedded", "prx:items").map { |i| i["id"] }
    assert_includes ids, episode.guid
    refute_includes ids, episode_prepublished.guid
    refute_includes ids, episode_unpublished.guid
  end

  it "should list for podcast" do
    refute_nil episode.id
    refute_nil episode_deleted.id
    refute_nil podcast.id
    get(:index, params: {api_version: "v1", format: "json", podcast_id: podcast.id})
    assert_response :success
    guids = JSON.parse(response.body)["_embedded"]["prx:items"].map { |p| p["id"] }
    assert_includes guids, episode.guid
    refute_includes guids, episode_deleted.guid
  end

  it "should filter by published date" do
    pubdate = episode.published_at

    get(:index, params: {api_version: "v1", format: "json"})
    assert_response :success
    assert_equal 1, JSON.parse(response.body)["_embedded"]["prx:items"].length

    get(:index, params: {api_version: "v1", format: "json", after: pubdate - 1.day, before: pubdate + 1.day})
    assert_response :success
    assert_equal 1, JSON.parse(response.body)["_embedded"]["prx:items"].length

    get(:index, params: {api_version: "v1", format: "json", after: pubdate + 1.day})
    assert_response :success
    assert_empty JSON.parse(response.body)["_embedded"]["prx:items"]

    get(:index, params: {api_version: "v1", format: "json", before: pubdate - 1.day})
    assert_response :success
    assert_empty JSON.parse(response.body)["_embedded"]["prx:items"]
  end

  describe "with a valid token" do
    let(:account_id) { 123 }
    let(:podcast) { create(:podcast, prx_account_uri: "/api/v1/accounts/#{account_id}") }
    let(:episode_redirect) { create(:episode, podcast: podcast, published_at: nil) }
    let(:episode_update) { create(:episode, podcast: podcast, published_at: nil) }
    let(:episode_with_image) { create(:episode_with_media, title: "Episode 1", podcast: podcast, published_at: Time.now - 1.hour) }

    let(:token) do
      StubToken.new(account_id,
        ["member feeder:read-private feeder:podcast-edit feeder:podcast-create feeder:episode feeder:episode-draft"])
    end

    around do |test|
      class << @controller; attr_accessor :prx_auth_token; end
      @controller.prx_auth_token = token
      @request.env["CONTENT_TYPE"] = "application/json"
      @controller.stub(:publish, true) do
        @controller.stub(:process_media, true) { test.call }
      end
    end

    it "should redirect for authorized request of unpublished resource" do
      refute_nil episode_redirect.id
      get(:show, params: {api_version: "v1", format: "json", id: episode_redirect.guid})
      assert_response :redirect
    end

    it "can create a new episode" do
      post(:create, body: episode_hash.to_json, as: :json,
        params: {api_version: "v1", format: "json", podcast_id: podcast.id})
      assert_response :success
      id = JSON.parse(response.body)["id"]
      new_episode = Episode.find_by_guid(id)
      assert_equal new_episode.prx_uri, "/api/v1/stories/123"
      assert_equal new_episode.contents.count, 3
      c = new_episode.contents.first
      assert_equal c.original_url, "https://s3.amazonaws.com/prx-testing/test/audio1.mp3"
    end

    it "can update on create of a new episode" do
      ep = create(:episode, published_at: (Time.now + 1.week), podcast: podcast, prx_uri: "/api/v1/stories/123")
      post(:create, body: episode_hash.to_json, as: :json,
        params: {api_version: "v1", format: "json", podcast_id: podcast.id})
      assert_response :success
      id = JSON.parse(response.body)["id"]
      new_episode = Episode.find_by_guid(id)
      assert_equal ep.id, new_episode.id

      assert_equal new_episode.contents.count, 3
      c = new_episode.contents.first
      assert_equal c.original_url, "https://s3.amazonaws.com/prx-testing/test/audio1.mp3"
    end

    it "can update the image on an episode" do
      assert_equal episode_with_image.title, "Episode 1"
      assert_equal episode_with_image.image.alt_text, "valid episode image"

      update_hash = {
        image: {
          altText: "new alt text"
        },
        title: "new title"
      }

      put(:update, body: update_hash.to_json, as: :json,
        params: {id: episode_with_image.guid, api_version: "v1", format: "json"})
      assert_response :success

      episode_with_image.reload
      assert_equal episode_with_image.title, "new title"
      assert_equal episode_with_image.image.alt_text, "new alt text"
    end

    it "can update audio on an episode" do
      update_hash = {
        media: [{
          href: "https://s3.amazonaws.com/prx-testing/test/change1.mp3",
          type: "audio/mpeg",
          size: 123456,
          duration: "1234.5678"
        }]
      }

      assert_equal episode_update.contents.size, 0
      assert_nil episode_update.medium

      put(:update, body: update_hash.to_json, as: :json,
        params: {id: episode_update.guid, api_version: "v1", format: "json"})
      assert_response :success

      episode_update.reload

      assert_equal "audio", episode_update.medium
      contents = episode_update.contents
      assert_equal contents.size, 1
      assert_equal contents.first.mime_type, "audio/mpeg"
      assert_equal contents.first.file_size, 123456
      assert_equal contents.first.duration.to_s, "1234.5678"
      guid1 = contents.first.guid

      # updating with a different href should insert it
      update_hash = {media: [{href: "s3://something/else"}]}
      put(:update, body: update_hash.to_json, as: :json,
        params: {id: episode_update.guid, api_version: "v1", format: "json"})
      assert_response :success

      contents = episode_update.reload.contents.with_deleted
      assert_equal contents.size, 2

      refute_equal contents.first.guid, guid1
      assert_equal contents.first.position, 1
      assert_nil contents.first.mime_type
      assert_nil contents.first.file_size
      assert_nil contents.first.duration

      assert_equal contents.last.guid, guid1
      assert_equal contents.last.position, 1
      assert_equal contents.last.mime_type, "audio/mpeg"
      assert_equal contents.last.file_size, 123456
      assert_equal contents.last.duration.to_s, "1234.5678"

      # updating without media does nothing
      update_hash = {title: "a new title"}
      put(:update, body: update_hash.to_json, as: :json,
        params: {id: episode_update.guid, api_version: "v1", format: "json"})
      assert_response :success
      assert_equal episode_update.reload.contents.size, 1

      # updating with an empty array deletes
      update_hash = {media: []}
      put(:update, body: update_hash.to_json, as: :json,
        params: {id: episode_update.guid, api_version: "v1", format: "json"})
      assert_response :success
      assert_equal episode_update.reload.contents.size, 0
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

      put(:update, body: update_hash.to_json, as: :json,
        params: {id: episode_update.guid, api_version: "v1", format: "json"})
      assert_response :success

      episode_update.reload

      contents = episode_update.contents
      assert_equal contents.size, 0

      uncut = episode_update.uncut
      assert_not_nil uncut
      assert_equal "uncut", episode_update.medium

      # updating with a nil should delete it
      update_hash = {uncut: nil}
      put(:update, body: update_hash.to_json, as: :json,
        params: {id: episode_update.guid, api_version: "v1", format: "json"})
      assert_response :success

      episode_update.reload

      assert_nil episode_update.uncut
      assert_nil episode_update.medium
    end
  end
end
