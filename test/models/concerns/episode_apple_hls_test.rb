require "test_helper"

describe EpisodeAppleHls do
  let(:episode) { create(:episode) }

  it "is not eligible for Apple HLS without HLS video" do
    refute episode.hls_eligible_for_apple?
    assert_nil episode.apple_hls_master_url(feed: episode.podcast.default_feed)
  end

  describe "with HLS video" do
    let(:video) { build_stubbed(:episode, medium: "video") }
    let(:uncut) { build_stubbed(:uncut_video, episode: video, status: "complete") }
    let(:hls) { AlternateMediaResource.from_uncut(uncut).tap { |a| a.status = "complete" } }

    before do
      video.association(:uncut).target = uncut
      video.association(:alternate_media_resource).target = hls
    end

    it "is eligible with a complete HLS transcode of the current upload" do
      assert video.hls_eligible_for_apple?
    end

    it "is not eligible while the current upload's HLS is processing or failed" do
      hls.status = "processing"
      refute video.hls_eligible_for_apple?

      hls.status = "error"
      refute video.hls_eligible_for_apple?
    end

    it "is not eligible when the complete HLS is for a replaced upload" do
      video.association(:uncut).target = build_stubbed(:uncut_video, episode: video, original_url: "s3://prx-testing/test/new.mp4")

      refute video.hls_eligible_for_apple?
    end

    it "is not eligible on a previous complete HLS alone" do
      video.stub(:ready_alt_media, build_stubbed(:alternate_media_resource, status: "complete")) do
        hls.status = "processing"
        refute video.hls_eligible_for_apple?
      end
    end

    it "is not eligible without an upload" do
      video.association(:uncut).target = nil

      refute video.hls_eligible_for_apple?
    end
  end

  it "uses the feed's HLS URL without its enclosure prefix" do
    feed = create(:feed, podcast: episode.podcast, slug: "hls", enclosure_prefix: "https://prefix.example/")

    episode.stub(:video?, true) do
      episode.stub(:hls_eligible_for_apple?, true) do
        url = episode.apple_hls_master_url(feed: feed)

        assert_equal episode.enclosure_alt_url(feed: feed, prefix: false), url
        refute_includes url, "prefix.example"
      end
    end
  end

  it "has HLS alternate asset mirror rows" do
    asset = create(:apple_hls_alternate_asset, episode: episode)

    assert_equal [asset], episode.apple_hls_alternate_assets.to_a
  end
end
