require "test_helper"

class EpisodeMediaTest < ActiveSupport::TestCase
  let(:c1) { build_stubbed(:content, status: "complete", position: 1) }
  let(:c2) { build_stubbed(:content, status: "complete", position: 2) }
  let(:ep) { build(:episode, segment_count: 2, contents: [c1, c2]) }

  describe "#validate_media_ready" do
    it "only runs on strict + published episodes with media" do
      e = build_stubbed(:episode, segment_count: 1)
      assert e.valid?

      e.strict_validations = true
      refute e.valid?

      e.published_at = nil
      assert e.valid?
    end

    it "checks for complete media on initial publish" do
      e = create(:episode_with_media, strict_validations: true, published_at: nil)
      assert e.valid?

      e.published_at = 1.hour.ago
      assert e.valid?

      e.contents.first.status = "invalid"
      refute e.valid?
      assert_includes e.errors[:base], "media not ready"
    end

    it "checks for present media on subsequent updates" do
      e = create(:episode_with_media, strict_validations: true, published_at: 1.hour.ago)
      assert e.valid?

      e.contents.first.status = "processing"
      assert e.valid?

      # also applies to uncut media
      e.medium = "uncut"
      e.uncut = nil
      refute e.valid?

      e.uncut = build(:uncut)
      assert e.valid?
    end
  end

  describe "#medium=" do
    let(:episode) { create(:episode_with_media) }

    it "marks existing content for destruction on change" do
      refute episode.contents.first.marked_for_destruction?

      episode.medium = "audio"
      refute episode.contents.first.marked_for_destruction?

      episode.medium = "uncut"
      assert episode.contents.first.marked_for_destruction?
      assert episode.uncut.new_record?
      assert_equal episode.contents.first.original_url, episode.uncut.original_url
    end

    it "sets segment count for videos" do
      episode.segment_count = 2
      refute episode.contents.first.marked_for_destruction?

      episode.medium = "video"
      assert episode.contents.first.marked_for_destruction?
      assert_equal 1, episode.segment_count
    end
  end

  describe "#segment_range" do
    it "returns a range of positions" do
      e = Episode.new(segment_count: nil)
      assert_equal [], e.segment_range.to_a

      e.segment_count = 1
      assert_equal [1], e.segment_range.to_a

      e.segment_count = 4
      assert_equal [1, 2, 3, 4], e.segment_range.to_a
    end
  end

  describe "#build_contents" do
    it "builds contents for missing positions" do
      e = Episode.new(segment_count: 3)
      c1 = e.contents.build(position: 2)
      _c2 = e.contents.build(position: 4)

      built = e.build_contents
      assert_equal 3, built.length
      assert_equal 1, built[0].position
      assert_equal c1, built[1]
      assert_equal 3, built[2].position
    end
  end

  describe "#destroy_out_of_range_contents" do
    let(:episode) { create(:episode_with_media) }

    it "marks contents for destruction" do
      c1 = episode.contents.create!(original_url: "c1", position: 2)
      c2 = episode.contents.create!(original_url: "c2", position: 4)

      episode.segment_count = nil
      episode.destroy_out_of_range_contents
      assert_nil c1.reload.deleted_at
      assert_nil c2.reload.deleted_at

      episode.segment_count = 3
      episode.destroy_out_of_range_contents
      assert_nil c1.reload.deleted_at
      refute_nil c2.reload.deleted_at
    end
  end

  describe ".feed_ready" do
    it "just in time creates new media versions" do
      episode = create(:episode, segment_count: 2)
      create(:content, episode: episode, position: 1, status: "complete")
      create(:content, episode: episode, position: 2, status: "complete")
      assert_empty episode.media_versions

      assert_equal Episode.where(id: episode.id).feed_ready.size, 1
      assert_equal episode.media_versions.size, 1
    end
  end

  describe "#feed_ready?" do
    it "indicates if an episode has complete media or needs no media" do
      episode = build_stubbed(:episode, medium: nil, segment_count: nil)
      assert episode.feed_ready?

      episode.medium = "audio"
      episode.stub(:complete_media, []) do
        refute episode.feed_ready?
      end

      episode.stub(:complete_media, [{what: "ev"}]) do
        assert episode.feed_ready?
      end
    end
  end

  describe "overrides media attributes" do
    it "mark as ready for external media complete" do
      episode = build_stubbed(:episode, medium: :audio, segment_count: nil)
      url = "https://prx.org/a.mp3"
      episode.stub(:complete_media, []) do
        refute episode.override?
        refute episode.feed_ready?

        episode.medium = :override
        episode.enclosure_override_url = nil
        assert episode.override?
        refute episode.feed_ready?

        episode.medium = :audio
        episode.enclosure_override_url = url
        assert episode.override?
        refute episode.override_ready?
        refute episode.feed_ready?

        episode.build_external_media_resource(status: "processing", original_url: url)
        refute episode.override_ready?
        refute episode.feed_ready?

        episode.build_external_media_resource(status: "complete", original_url: url)
        assert episode.override_ready?
        assert episode.feed_ready?
      end
    end

    it "creates override media when override url set" do
      episode = create(:episode, segment_count: 2)
      assert_nil episode.external_media_resource
      episode.enclosure_override_url = "https://prx.org/a.mp3"
      ExternalMediaResource.stub_any_instance(:analyze_media, true) do
        episode.save!
      end
      assert_equal episode.external_media_resource.original_url, "https://prx.org/a.mp3"
    end

    it "creates override media when override url updated" do
      ExternalMediaResource.stub_any_instance(:analyze_media, true) do
        episode = create(:episode, enclosure_override_url: "https://prx.org/a.mp3")
        assert_equal episode.external_media_resource.original_url, "https://prx.org/a.mp3"
        emr_id = episode.external_media_resource.id
        episode.external_media_resource

        episode.update(enclosure_override_url: "https://prx.org/new.mp3")
        assert_equal episode.external_media_resource.original_url, "https://prx.org/new.mp3"
        assert emr_id != episode.external_media_resource.id
      end
    end

    it "overrides media content type" do
      c1.mime_type = "some/thing1"
      assert_equal "some/thing1", ep.media_content_type

      ep.enclosure_override_url = "https://prx.org/a.mp3"
      ep.build_external_media_resource(status: "complete", mime_type: "some/thing2")
      assert_equal "some/thing2", ep.media_content_type
    end

    it "overrides media content type" do
      assert_equal 96.00, ep.media_duration

      ep.enclosure_override_url = "https://prx.org/a.mp3"
      ep.build_external_media_resource(status: "complete", duration: 240)
      assert_equal 240.00, ep.media_duration
    end

    it "overrides media file size" do
      assert_equal 1548118, ep.media_file_size

      ep.enclosure_override_url = "https://prx.org/a.mp3"
      ep.build_external_media_resource(status: "complete", file_size: 2222222)
      assert_equal 2222222, ep.media_file_size
    end

    it "overrides media status" do
      assert_equal "complete", ep.media_status

      ep.enclosure_override_url = "https://prx.org/a.mp3"
      ep.build_external_media_resource(status: "processing")
      assert_equal "processing", ep.media_status
    end
  end

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
      assert c2.marked_for_destruction?

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
    end

    it "ignores nil" do
      ep.media = nil

      assert_equal [c1, c2], ep.media
      assert ep.media.none?(&:marked_for_destruction?)
    end

    it "ignores unchanged original_urls" do
      ep.media = [c1.original_url, c2.original_url]

      assert_equal [c1, c2], ep.media
      assert ep.media.none?(&:marked_for_destruction?)
    end

    it "also accepts hashes" do
      ep.media = [{original_url: c1.original_url}, {href: c2.original_url}]

      assert_equal [c1, c2], ep.media
      assert ep.media.none?(&:marked_for_destruction?)
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
      assert_equal "incomplete", build_stubbed(:episode, contents: []).media_status
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
