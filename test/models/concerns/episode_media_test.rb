require "test_helper"

class EpisodeMediaTest < ActiveSupport::TestCase
  let(:c1) { build_stubbed(:content, status: "complete", position: 1) }
  let(:c2) { build_stubbed(:content, status: "complete", position: 2) }
  let(:ep) { build(:episode, segment_count: 2, contents: [c1, c2]) }

  describe "#cut_media_version!" do
    it "creates new media versions" do
      episode = create(:episode, segment_count: 2)
      assert_empty episode.media_versions

      c1 = create(:content, episode: episode, position: 1, status: "complete")
      c2 = create(:content, episode: episode, position: 2, status: "complete")
      v1 = episode.cut_media_version!

      # repeat calls have no effect
      assert_equal v1, episode.cut_media_version!
      assert_equal v1, episode.cut_media_version!
      assert_equal 1, episode.media_versions.size
      assert_equal 2, v1.media_version_resources.size
      assert_equal [c1, c2], v1.media_resources

      # replacing c2, but processing not done - same old version
      c3 = create(:content, episode: episode, position: 2, status: "processing")
      assert_equal v1, episode.reload.cut_media_version!
      assert c2.reload.deleted?
      assert_equal [c1, c2], v1.reload.media_resources
      assert_equal 1, episode.media_versions.size

      # new version when processing completes
      c3.update(status: "complete")
      v2 = episode.reload.cut_media_version!
      refute_equal v1, v2
      assert_equal [c1, c3], v2.media_resources
      assert_equal 2, episode.media_versions.size
    end

    it "creates no media versions until complete" do
      episode = create(:episode, segment_count: 2)
      assert_empty episode.media_versions

      create(:content, episode: episode, position: 1, status: "complete")
      create(:content, episode: episode, position: 2, status: "processing")

      assert_nil episode.cut_media_version!
      assert_equal 0, episode.media_versions.size
    end
  end

  describe "#media_version_id" do
    it "cuts a version and returns its id" do
      ep.stub(:cut_media_version!, MediaVersion.new(id: 1234)) do
        assert_equal 1234, ep.media_version_id
      end
    end

    it "handles non ready media" do
      ep.stub(:cut_media_version!, nil) do
        assert_nil ep.media_version_id
      end
    end
  end

  describe "#complete_media" do
    it "returns the current media version resources" do
      mock = Minitest::Mock.new
      mock.expect(:media_resources, [])

      ep.stub(:cut_media_version!, mock) do
        assert_equal [], ep.complete_media
        mock.verify
      end
    end

    it "returns an empty array for non ready media" do
      ep.stub(:cut_media_version!, nil) do
        assert_equal [], ep.complete_media
      end
    end
  end

  describe "#complete_media?" do
    it "checks for any complete_media" do
      ep.stub(:complete_media, []) do
        refute ep.complete_media?
      end

      ep.stub(:complete_media, ["anything"]) do
        assert ep.complete_media?
      end
    end
  end

  describe "#media?" do
    it "allows episodes to have no media" do
      refute build_stubbed(:episode, medium: nil, segment_count: nil, contents: []).media?
      assert build_stubbed(:episode, medium: "audio", segment_count: nil, contents: []).media?
      assert build_stubbed(:episode, medium: nil, segment_count: 1, contents: []).media?
      assert build_stubbed(:episode, medium: nil, segment_count: nil, contents: [c1]).media?
    end
  end

  describe "#media" do
    it "returns episode contents" do
      assert_equal 2, ep.media.size
      assert_equal [c1, c2], ep.media
    end
  end

  describe "#media=" do
    it "replaces contents" do
      ep.media = [c1, "http://some.changed/url.mp3"]

      assert_equal 2, ep.media.size
      assert_equal 3, ep.contents.size
      assert_equal c1, ep.contents[0]
      assert_equal c2, ep.contents[1]
      assert c2.marked_for_replacement?

      new_content = ep.contents[2]
      assert new_content.new_record?
      assert_equal "http://some.changed/url.mp3", new_content.original_url
      assert_equal 2, new_content.position
    end

    it "adds contents" do
      ep.media = [c1, c2, "http://some.new/url.mp3"]

      assert_equal 3, ep.media.size
      assert_equal c1, ep.media[0]
      assert_equal c2, ep.media[1]
      refute c2.marked_for_destruction?
      refute c2.marked_for_replacement?

      new_content = ep.media[2]
      assert new_content.new_record?
      assert_equal "http://some.new/url.mp3", new_content.original_url
      assert_equal 3, new_content.position
    end

    it "removes contents" do
      ep.media = [c1]

      assert_equal 1, ep.media.size
      assert_equal 2, ep.contents.size
      assert_equal c1, ep.contents[0]
      assert_equal c2, ep.contents[1]

      assert c2.marked_for_destruction?
      refute c2.marked_for_replacement?
    end

    it "ignores nil" do
      ep.media = nil

      assert_equal [c1, c2], ep.media
      assert ep.media.none?(&:marked_for_destruction?)
      assert ep.media.none?(&:marked_for_replacement?)
    end

    it "ignores unchanged original_urls" do
      ep.media = [c1.original_url, c2.original_url]

      assert_equal [c1, c2], ep.media
      assert ep.media.none?(&:marked_for_destruction?)
      assert ep.media.none?(&:marked_for_replacement?)
    end

    it "also accepts hashes" do
      ep.media = [{original_url: c1.original_url}, {href: c2.original_url}]

      assert_equal [c1, c2], ep.media
      assert ep.media.none?(&:marked_for_destruction?)
      assert ep.media.none?(&:marked_for_replacement?)
    end

    it "infers episode medium audio" do
      assert_nil ep.medium
      ep.media = ["http://some.new/url.mp3", "http://some.new/url.wav"]
      assert_equal "audio", ep.medium
    end

    it "infers episode medium video" do
      ep.media = ["http://some.new/url.mov", "http://some.new/url.mp4"]
      assert_equal "video", ep.medium
    end

    it "defaults to audio" do
      assert_nil ep.medium
      ep.media = []
      assert_equal "audio", ep.medium
    end

    it "handles non-arrays" do
      ep.media = c1.original_url

      assert_equal 1, ep.media.size
      assert_equal 2, ep.contents.size
      assert_equal c1, ep.contents[0]
      assert_equal c2, ep.contents[1]

      assert c2.marked_for_destruction?
      refute c2.marked_for_replacement?
    end
  end

  describe "#media_content_type" do
    it "returns the first contents type" do
      c1.mime_type = "some/thing1"
      c2.mime_type = "some/thing2"

      assert_equal "some/thing1", ep.media_content_type
    end

    it "overrides with a feed mime type" do
      feed = build_stubbed(:feed, audio_format: nil)
      assert_equal "audio/mpeg", ep.media_content_type(feed)

      # feed overrides audio mimes
      feed.audio_format = {f: "flac"}
      assert_equal "audio/flac", ep.media_content_type(feed)

      # but not video/other mimes
      c1.mime_type = "video/mp4"
      assert_equal "video/mp4", ep.media_content_type(feed)
      c1.mime_type = "some/thing"
      assert_equal "some/thing", ep.media_content_type(feed)
    end
  end

  describe "#media_duration" do
    it "sums media durations" do
      c1.duration = 1.11
      c2.duration = 2.22

      assert_equal 3.33, ep.media_duration
    end

    it "includes podcast duration padding" do
      c1.duration = 1.11
      c2.duration = 2.22
      ep.podcast.duration_padding = 1.11

      assert_equal 4.44, ep.media_duration
    end
  end

  describe "#media_file_size" do
    it "sums file sizes" do
      c1.file_size = 1111
      c2.file_size = 2222

      assert_equal 3333, ep.media_file_size
    end
  end

  describe "#media_ready?" do
    it "checks for empty contents" do
      refute build_stubbed(:episode, contents: []).media_ready?
    end

    it "checks for incomplete contents" do
      c1.status = "complete"
      c2.status = "invalid"

      refute ep.media_ready?
      refute ep.media_ready?(true)

      # optionally ignores status
      assert ep.media_ready?(false)
    end

    it "checks segment count" do
      assert ep.media_ready?

      ep.segment_count = 3
      refute ep.media_ready?

      # segment count can be smaller than ep.contents - they will get trimmed
      # by the destroy_out_of_range_contents after save
      ep.segment_count = 1
      assert ep.media_ready?
    end

    it "counts positions if segment count is nil" do
      ep.segment_count = nil
      assert ep.media_ready?

      c2.position = 3
      refute ep.media_ready?
    end
  end

  describe "#media_status" do
    it "checks for all completed contents" do
      assert_equal "complete", ep.media_status
    end

    it "checks for any processing contents" do
      c2.status = "started"
      assert_equal "processing", ep.media_status
    end

    it "checks for any errored contents" do
      c2.status = "error"
      assert_equal "error", ep.media_status
    end

    it "checks for any invalid contents" do
      c2.status = "invalid"
      assert_equal "invalid", ep.media_status
    end

    it "handles empty contents" do
      assert_nil build_stubbed(:episode, contents: []).media_status
    end
  end

  describe "#media_url" do
    it "returns the first contents href" do
      c1.stub(:href, "some-href") do
        assert_equal "some-href", ep.media_url
      end
    end
  end
end
