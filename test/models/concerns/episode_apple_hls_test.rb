require "test_helper"

describe EpisodeAppleHls do
  let(:episode) { create(:episode) }

  it "is not eligible for Apple HLS until the HLS media pipeline lands" do
    refute episode.hls_eligible_for_apple?
    assert_nil episode.apple_hls_master_url(feed: episode.podcast.default_feed)
  end

  it "requires a ready HLS video to be eligible" do
    feed = episode.podcast.default_feed

    episode.stub(:video?, true) do
      refute episode.hls_eligible_for_apple?

      episode.stub(:ready_alt_media, Object.new) do
        episode.stub(:enclosure_alt_url, ->(feed:) { "https://dovetail/#{feed.id}/ep.m3u8" }) do
          assert episode.hls_eligible_for_apple?
          assert_equal "https://dovetail/#{feed.id}/ep.m3u8", episode.apple_hls_master_url(feed: feed)
        end
      end
    end
  end

  it "has HLS alternate asset mirror rows" do
    asset = create(:apple_hls_alternate_asset, episode: episode)

    assert_equal [asset], episode.apple_hls_alternate_assets.to_a
  end
end
