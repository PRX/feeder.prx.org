require "test_helper"

module Apple
  describe HlsAlternateAsset do
    let(:podcast) { create(:podcast) }
    let(:episode) { create(:episode, podcast: podcast) }
    let(:show_feed_binding) { create(:apple_show_feed_binding, feed: create(:public_feed, podcast: podcast), apple_show_id: "show-1") }
    let(:guid) { "guid-1" }
    let(:staged_json) { {"id" => "staged-1", "attributes" => {"alternateAssetContentUrl" => "https://example.com/a.m3u8"}} }

    def upsert(**opts)
      HlsAlternateAsset.upsert_from_apple!(episode: episode, show_feed_binding: show_feed_binding, feeder_guid: guid, **opts)
    end

    it "enforces one row per podcast, show, and GUID" do
      create(:apple_hls_alternate_asset, episode: episode, apple_show_id: "show-1", feeder_guid: guid)
      dup = build(:apple_hls_alternate_asset, episode: episode, apple_show_id: "show-1", feeder_guid: guid)

      refute dup.valid?
      assert build(:apple_hls_alternate_asset, episode: episode, apple_show_id: "show-2", feeder_guid: guid).valid?
    end

    describe ".upsert_from_apple!" do
      it "records a staged asset" do
        asset = upsert(resource_type: :staged_alternate_asset, response: staged_json)

        assert asset.staged?
        assert_equal "staged-1", asset.staged_alternate_asset_id
        assert_equal "https://example.com/a.m3u8", asset.content_url
        assert_equal [podcast.id, "show-1", guid], [asset.feeder_podcast_id, asset.apple_show_id, asset.feeder_guid]
        assert_equal episode, asset.episode
        assert asset.last_checked_at.present?
      end

      it "updates the same row when the asset links to an Apple episode" do
        staged = upsert(resource_type: :staged_alternate_asset, response: staged_json)
        episode_json = {"id" => "ep-1", "attributes" => {"alternateAssetContentUrl" => "https://example.com/b.m3u8"}}

        linked = upsert(resource_type: :episode, response: episode_json)

        assert_equal staged.id, linked.id
        assert linked.linked?
        assert_equal "ep-1", linked.apple_episode_id
        assert_equal "https://example.com/b.m3u8", linked.content_url
        assert_equal 1, HlsAlternateAsset.count
      end

      it "records Apple errors and clears them on success" do
        upsert(resource_type: :staged_alternate_asset, response: staged_json)

        failed = upsert(error: StandardError.new("boom"))
        assert failed.error?
        assert_equal "boom", failed.last_error
        assert_equal "staged-1", failed.staged_alternate_asset_id

        recovered = upsert(resource_type: :staged_alternate_asset, response: staged_json)
        assert recovered.staged?
        assert_nil recovered.last_error
      end

      it "rejects unknown resource types" do
        assert_raises(ArgumentError) { upsert(resource_type: :show) }
        assert_raises(ArgumentError) { upsert(resource_type: nil) }
      end
    end
  end
end
