require "test_helper"

module Apple
  describe HlsAlternateAsset do
    let(:podcast) { create(:podcast) }
    let(:episode) { create(:episode, podcast: podcast) }
    let(:binding) { create(:apple_show_feed_binding, feed: create(:public_feed, podcast: podcast), apple_show_id: "show-1") }
    let(:guid) { "guid-1" }
    let(:staged_json) { {"id" => "staged-1", "attributes" => {"alternateAssetContentUrl" => "https://example.com/a.m3u8"}} }

    def upsert(**opts)
      HlsAlternateAsset.upsert_from_apple!(episode: episode, binding: binding, feeder_guid: guid, **opts)
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
        apple_episode = Struct.new(:apple_json).new({"attributes" => {"alternateAssetContentUrl" => "https://example.com/b.m3u8"}})

        linked = upsert(resource_type: :episode, apple_episode: apple_episode)

        assert_equal staged.id, linked.id
        assert linked.linked?
        assert_equal "https://example.com/b.m3u8", linked.content_url
        assert_equal 1, HlsAlternateAsset.count
      end

      it "returns nil when Apple has nothing and there is no prior row" do
        assert_nil upsert(resource_type: nil)
        assert_equal 0, HlsAlternateAsset.count
      end

      it "marks a vanished staged asset expired" do
        upsert(resource_type: :staged_alternate_asset, response: staged_json)

        asset = upsert(resource_type: nil)

        assert asset.expired?
        assert_equal "staged-1", asset.staged_alternate_asset_id
      end

      it "marks a vanished linked episode as an error" do
        upsert(resource_type: :episode, apple_episode: nil)

        asset = upsert(resource_type: nil)

        assert asset.error?
        assert_match(/no longer reports/, asset.last_error)
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
      end
    end
  end
end
