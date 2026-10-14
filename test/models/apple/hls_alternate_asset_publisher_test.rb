require "test_helper"

module Apple
  describe HlsAlternateAssetPublisher do
    let(:api_base) { "https://aardvark.prx.org" }
    let(:podcast) do
      podcast = create(:podcast)
      podcast.update!(apple_key: create(:apple_key, account_id: podcast.account_id))
      podcast
    end
    let(:feed) { create(:public_feed, podcast: podcast) }
    let(:show_feed_binding) { create(:apple_show_feed_binding, feed: feed, apple_show_id: "show-1") }
    let(:episode) { hls_episode("https://dovetail.test/ep1.m3u8") }

    def hls_episode(url, eligible: true)
      episode = create(:episode, podcast: podcast)
      episode.define_singleton_method(:hls_eligible_for_apple?) { eligible }
      episode.define_singleton_method(:apple_hls_master_url) { |feed:| url if eligible }
      episode
    end

    def collection(data)
      {status: 200, body: {data: data, links: {self: "#{api_base}/x"}}.to_json}
    end

    def stub_apple_episodes(data)
      stub_request(:get, "#{api_base}/shows/show-1/episodes").to_return(collection(data))
    end

    def stub_staged_assets(data)
      stub_request(:get, "#{api_base}/shows/show-1/stagedAlternateAssets").to_return(collection(data))
    end

    def apple_episode_json(guid, url: nil, id: "ep-1", kind: HlsAlternateAsset::CONTENT_KIND, mime_type: HlsAlternateAsset::MIME_TYPE)
      attributes = {"guid" => guid, "alternateAssetContentUrl" => url}
      if url
        attributes["alternateAssetContentKind"] = kind
        attributes["alternateAssetMimeType"] = mime_type
      end
      {"id" => id, "type" => "episodes", "attributes" => attributes}
    end

    def staged_json(guid, url, id: "staged-1")
      {"id" => id, "type" => "stagedAlternateAssets", "attributes" => {"guid" => guid, "alternateAssetContentUrl" => url}}
    end

    def publish(*episodes)
      HlsAlternateAssetPublisher.publish!(show_feed_binding: show_feed_binding, episodes: episodes)
    end

    def mirror(episode, guid: episode.item_guid)
      HlsAlternateAsset.find_by(feeder_podcast_id: podcast.id, apple_show_id: "show-1", feeder_guid: guid)
    end

    it "makes no Apple requests without an eligible episode" do
      assert_equal [], publish(hls_episode("https://dovetail.test/x.m3u8", eligible: false))
      assert_not_requested :any, /#{api_base}/
    end

    it "stages an episode Apple has not seen" do
      stub_apple_episodes([])
      stub_staged_assets([])
      create_stub = stub_request(:post, "#{api_base}/stagedAlternateAssets")
        .with { |req|
          data = JSON.parse(req.body)["data"]
          data["attributes"] == {
            "alternateAssetContentUrl" => "https://dovetail.test/ep1.m3u8",
            "alternateAssetContentKind" => "VIDEO",
            "alternateAssetMimeType" => "application/vnd.apple.mpegurl",
            "guid" => episode.item_guid
          } && data.dig("relationships", "show", "data") == {"type" => "shows", "id" => "show-1"}
        }
        .to_return(status: 201, body: {data: staged_json(episode.item_guid, "https://dovetail.test/ep1.m3u8")}.to_json)

      publish(episode)

      assert_requested create_stub
      asset = mirror(episode)
      assert asset.staged?
      assert_equal "staged-1", asset.staged_alternate_asset_id
      assert_equal "https://dovetail.test/ep1.m3u8", asset.content_url
    end

    it "patches a linked episode whose URL differs without reading staged assets" do
      stub_apple_episodes([apple_episode_json(episode.item_guid, url: "https://dovetail.test/old.m3u8")])
      staged_stub = stub_staged_assets([])
      patch_stub = stub_request(:patch, "#{api_base}/episodes/ep-1")
        .with { |req| JSON.parse(req.body).dig("data", "attributes", "alternateAssetContentUrl") == "https://dovetail.test/ep1.m3u8" }
        .to_return(status: 200, body: {data: apple_episode_json(episode.item_guid, url: "https://dovetail.test/ep1.m3u8")}.to_json)

      publish(episode)

      assert_requested patch_stub
      assert_not_requested staged_stub
      asset = mirror(episode)
      assert asset.linked?
      assert_equal "ep-1", asset.apple_episode_id
      assert_equal "https://dovetail.test/ep1.m3u8", asset.content_url
      assert_equal 0, SyncLog.apple.episodes.count
    end

    it "patches a linked episode whose URL matches but content kind or MIME type differs" do
      stub_apple_episodes([apple_episode_json(episode.item_guid, url: "https://dovetail.test/ep1.m3u8", kind: nil, mime_type: "audio/mpeg")])
      patch_stub = stub_request(:patch, "#{api_base}/episodes/ep-1")
        .with { |req|
          JSON.parse(req.body).dig("data", "attributes") == {
            "alternateAssetContentUrl" => "https://dovetail.test/ep1.m3u8",
            "alternateAssetContentKind" => HlsAlternateAsset::CONTENT_KIND,
            "alternateAssetMimeType" => HlsAlternateAsset::MIME_TYPE
          }
        }
        .to_return(status: 200, body: {data: apple_episode_json(episode.item_guid, url: "https://dovetail.test/ep1.m3u8")}.to_json)

      publish(episode)

      assert_requested patch_stub
      assert mirror(episode).linked?
    end

    it "logs and skips an archived linked episode" do
      archived = apple_episode_json(episode.item_guid, url: "https://dovetail.test/old.m3u8")
      archived["attributes"]["publishingState"] = "ARCHIVED"
      stub_apple_episodes([archived])

      logs = capture_json_logs { publish(episode) }

      assert_not_requested :patch, /#{api_base}/
      assert mirror(episode).linked?
      assert_equal "https://dovetail.test/old.m3u8", mirror(episode).content_url
      log = logs.find { |line| line["msg"] == "Apple HLS linked episode is archived, skipping" }
      assert_equal "ep-1", log["apple_episode_id"]
      assert_equal 50, log["level"]
    end

    it "only records a linked episode whose alternate asset matches" do
      stub_apple_episodes([apple_episode_json(episode.item_guid, url: "https://dovetail.test/ep1.m3u8")])

      publish(episode)

      assert_not_requested :patch, /#{api_base}/
      assert mirror(episode).linked?
      assert_equal "ep-1", mirror(episode).apple_episode_id
      assert_equal 0, SyncLog.apple.episodes.count
    end

    it "patches a staged asset whose URL differs" do
      stub_apple_episodes([])
      stub_staged_assets([staged_json(episode.item_guid, "https://dovetail.test/old.m3u8")])
      patch_stub = stub_request(:patch, "#{api_base}/stagedAlternateAssets/staged-1")
        .with { |req| JSON.parse(req.body).dig("data", "attributes") == {"alternateAssetContentUrl" => "https://dovetail.test/ep1.m3u8"} }
        .to_return(status: 200, body: {data: staged_json(episode.item_guid, "https://dovetail.test/ep1.m3u8")}.to_json)

      publish(episode)

      assert_requested patch_stub
      assert_not_requested :post, /#{api_base}/
      assert_equal "https://dovetail.test/ep1.m3u8", mirror(episode).content_url
    end

    it "re-stages an expired staged asset" do
      create(:apple_hls_alternate_asset, episode: episode, apple_show_id: "show-1", feeder_guid: episode.item_guid,
        staged_alternate_asset_id: "staged-old")
      stub_apple_episodes([])
      stub_staged_assets([])
      stub_request(:post, "#{api_base}/stagedAlternateAssets")
        .to_return(status: 201, body: {data: staged_json(episode.item_guid, "https://dovetail.test/ep1.m3u8", id: "staged-new")}.to_json)

      logs = capture_json_logs { publish(episode) }

      asset = mirror(episode)
      assert asset.staged?
      assert_equal "staged-new", asset.staged_alternate_asset_id
      assert_equal 1, HlsAlternateAsset.count
      log = logs.find { |line| line["msg"] == "Apple HLS staged asset expired, re-staging" }
      assert_equal "staged-old", log["staged_alternate_asset_id"]
    end

    it "logs and re-stages a vanished linked episode" do
      create(:apple_hls_alternate_asset, episode: episode, apple_show_id: "show-1", feeder_guid: episode.item_guid,
        status: :linked, apple_episode_id: "ep-old")
      stub_apple_episodes([])
      stub_staged_assets([])
      stub_request(:post, "#{api_base}/stagedAlternateAssets")
        .to_return(status: 201, body: {data: staged_json(episode.item_guid, "https://dovetail.test/ep1.m3u8")}.to_json)

      logs = capture_json_logs { publish(episode) }

      assert mirror(episode).staged?
      log = logs.find { |line| line["msg"] == "Apple HLS linked episode vanished, re-staging" }
      assert_equal "ep-old", log["apple_episode_id"]
    end

    it "records a failed write and continues with the next episode" do
      other = hls_episode("https://dovetail.test/ep2.m3u8")
      stub_apple_episodes([])
      stub_staged_assets([])
      stub_request(:post, "#{api_base}/stagedAlternateAssets")
        .with { |req| JSON.parse(req.body).dig("data", "attributes", "guid") == episode.item_guid }
        .to_return(status: 500, body: {errors: [{status: "500"}]}.to_json)
      stub_request(:post, "#{api_base}/stagedAlternateAssets")
        .with { |req| JSON.parse(req.body).dig("data", "attributes", "guid") == other.item_guid }
        .to_return(status: 201, body: {data: staged_json(other.item_guid, "https://dovetail.test/ep2.m3u8", id: "staged-2")}.to_json)

      publish(episode, other)

      assert mirror(episode).error?
      assert mirror(episode).last_error.present?
      assert mirror(other).staged?
    end

    it "sends a failed create once" do
      stub_apple_episodes([])
      stub_staged_assets([])
      create_stub = stub_request(:post, "#{api_base}/stagedAlternateAssets")
        .to_return(status: 500, body: {errors: [{status: "500"}]}.to_json)

      publish(episode)

      assert_requested create_stub, times: 1
      assert mirror(episode).error?
    end

    it "raises when a bulk read fails" do
      stub_request(:get, "#{api_base}/shows/show-1/episodes").to_return(status: 500, body: {errors: []}.to_json)

      assert_raises(Apple::ApiError) { publish(episode) }
      assert_nil mirror(episode)
    end

    it "matches on the feed-scoped RSS GUID" do
      feed.update!(unique_guids: true)
      guid = "#{episode.item_guid}_#{feed.id}"
      stub_apple_episodes([apple_episode_json(episode.item_guid, url: "https://dovetail.test/audio-only.m3u8")])
      stub_staged_assets([])
      create_stub = stub_request(:post, "#{api_base}/stagedAlternateAssets")
        .with { |req| JSON.parse(req.body).dig("data", "attributes", "guid") == guid }
        .to_return(status: 201, body: {data: staged_json(guid, "https://dovetail.test/ep1.m3u8")}.to_json)

      publish(episode)

      assert_requested create_stub
      assert_not_requested :patch, /#{api_base}/
      assert mirror(episode, guid: guid).staged?
    end
  end
end
