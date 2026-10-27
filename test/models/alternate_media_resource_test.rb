require "test_helper"

describe AlternateMediaResource do
  let(:ep) { build_stubbed(:episode) }
  let(:uncut) { build_stubbed(:uncut_video, episode: ep) }

  describe ".from_uncut" do
    it "copies metadata from the uncut media" do
      alt = AlternateMediaResource.from_uncut(uncut)

      assert alt.url.ends_with?("/index.m3u8")
      assert_equal uncut.url, alt.original_url
      assert_equal "application/x-mpegURL", alt.mime_type
      assert_equal "video", alt.medium
      assert_equal uncut.duration, alt.duration
      assert_equal uncut.bit_rate, alt.bit_rate
    end
  end

  describe "#same_uncut?" do
    it "checks the source url and segmentation" do
      alt = AlternateMediaResource.new(original_url: uncut.url, segmentation: uncut.segmentation)
      assert alt.same_uncut?(uncut)

      alt.original_url = "http://something/else.mp4"
      refute alt.same_uncut?(uncut)

      alt.original_url = uncut.url
      alt.segmentation = uncut.segmentation + [9999, 10000]
      refute alt.same_uncut?(uncut)
    end
  end

  describe "#media_url" do
    it "uses an m3u8 file extension" do
      alt = AlternateMediaResource.new(original_url: "http://some.where/file.mp4", episode: ep)

      assert_equal "index.m3u8", alt.file_name
      assert_equal "#{ep.base_published_url}/#{alt.guid}/index.m3u8", alt.url
    end
  end

  describe "#variant_url" do
    it "puts all variants in the subdir" do
      alt = AlternateMediaResource.new(original_url: "http://some.where/file.mp4", episode: ep)

      assert_equal "#{ep.base_published_url}/#{alt.guid}/index.m3u8", alt.variant_url("index.m3u8")
      assert_equal "#{ep.base_published_url}/#{alt.guid}/1080p.ts", alt.variant_url("1080p.ts")
      assert_equal "#{ep.base_published_url}/#{alt.guid}/what.ev", alt.variant_url("what.ev")
    end
  end

  describe "#after_hls_transcode" do
    let(:alt) { create(:alternate_media_resource, episode: create(:episode)).tap { |a| a.update_columns(status: "processing") } }

    it "publishes the episode when the transcode completes" do
      publish = Minitest::Mock.new
      publish.expect(:call, nil)

      alt.episode.stub(:publish!, publish) do
        alt.update!(status: "complete")
        alt.after_hls_transcode(nil)
      end

      assert publish.verify
    end

    it "does not republish when the status is unchanged" do
      publish = Minitest::Mock.new
      alt.update!(status: "complete")
      alt.update!(updated_at: Time.now)

      alt.episode.stub(:publish!, publish) do
        alt.after_hls_transcode(nil)
      end

      assert publish.verify
    end
  end
end
