require "test_helper"

describe EpisodeAppleHls do
  let(:episode) { create(:episode) }

  it "is not eligible for Apple HLS without HLS video" do
    refute episode.hls_eligible_for_apple?
    assert_nil episode.apple_hls_master_url(feed: episode.podcast.default_feed)
  end

  it "requires a ready HLS video to be eligible" do
    episode.stub(:video?, true) do
      refute episode.hls_eligible_for_apple?

      episode.stub(:ready_alt_media, Object.new) do
        assert episode.hls_eligible_for_apple?
      end
    end
  end

  it "uses the feed's HLS URL without its enclosure prefix" do
    feed = create(:feed, podcast: episode.podcast, slug: "hls", enclosure_prefix: "https://prefix.example/")

    episode.stub(:video?, true) do
      episode.stub(:ready_alt_media, Object.new) do
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
