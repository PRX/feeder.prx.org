require "test_helper"

describe EpisodeTimingsImport do
  let(:import) { EpisodeTimingsImport.new }

  describe ".parse_timings" do
    it "parses timings" do
      assert_equal [1.23], EpisodeTimingsImport.parse_timings("1.23")
      assert_equal [1.23, 4.56], EpisodeTimingsImport.parse_timings(" 1.23 , 4.56")
      assert_equal [1.23, 4.56, 6], EpisodeTimingsImport.parse_timings(" 1.23 , 4.56,6")
    end

    it "handles brackets" do
      assert_equal [1.23], EpisodeTimingsImport.parse_timings("[1.23]")
      assert_equal [1.23, 4.56], EpisodeTimingsImport.parse_timings("{ 1.23 , 4.56}")
      assert_equal [1.23, 4.56, 6], EpisodeTimingsImport.parse_timings("[ 1.23 , 4.56,6]")
    end

    it "handles empty" do
      assert_equal [], EpisodeTimingsImport.parse_timings("")
      assert_equal [], EpisodeTimingsImport.parse_timings(" ")
      assert_equal [], EpisodeTimingsImport.parse_timings(" {} ")
      assert_equal [], EpisodeTimingsImport.parse_timings("[] ")
    end

    it "requires positive numbers" do
      assert_nil EpisodeTimingsImport.parse_timings("7.6a")
      assert_nil EpisodeTimingsImport.parse_timings("[0]")
      assert_nil EpisodeTimingsImport.parse_timings("[-4.4]")
      assert_nil EpisodeTimingsImport.parse_timings("-4, 5")
      refute_nil EpisodeTimingsImport.parse_timings("5, 6.6")
    end

    it "requires at least one decimal when strict" do
      assert_nil EpisodeTimingsImport.parse_timings("4,6.000000", true)
      refute_nil EpisodeTimingsImport.parse_timings("4,6.000000", false)
      refute_nil EpisodeTimingsImport.parse_timings("4,6.000001", true)
    end

    it "sorts timings" do
      assert_equal [1.23, 4.56, 6], EpisodeTimingsImport.parse_timings("[ 1.23, 6, 4.56]")
    end

    it "combings timings that are close together" do
      assert_equal [1.23, 4.56], EpisodeTimingsImport.parse_timings("1.23, 1.23, 1.23001, 4.56")
      assert_equal [1.23, 4.56], EpisodeTimingsImport.parse_timings("1.23, 4.56, 1.23001")
    end
  end

  describe "#parse_timings" do
    it "parses import timings" do
      import.timings = "1.23, 4.56"
      assert_equal [1.23, 4.56], import.parse_timings
    end
  end

  describe "#import!" do
    let(:podcast_import) { create(:podcast_timings_import) }
    let(:import) { EpisodeTimingsImport.create(podcast_import: podcast_import, guid: "abcd", timings: "1.23,4.56") }
    let(:episode) { create(:episode, original_guid: "abcd", podcast: podcast_import.podcast) }
    let(:uncut) { create(:uncut, episode: episode, segmentation: [[1.2, 3.4]]) }
    let(:content1) { create(:content, episode: episode, position: 1) }
    let(:content2) { create(:content, episode: episode, position: 2) }

    it "requires an episode" do
      assert import.status_created?
      import.import!
      assert import.status_not_found?
    end

    it "requires valid timings" do
      assert episode.present?
      assert_nil import.episode

      import.timings = "-2"
      import.import!
      assert import.status_bad_timings?
      assert_equal episode.id, import.episode_id
    end

    it "requires media" do
      assert episode.present?

      import.import!
      assert import.status_no_media?
      assert_equal episode.id, import.episode_id
    end

    it "leaves segmentation alone if empty timings" do
      assert uncut.present?

      import.timings = "[]"
      import.import!
      assert import.status_complete?
      assert_equal [[1.2, 3.4]], uncut.reload.segmentation
    end

    it "will not convert multi-content episodes" do
      assert content1.present?
      assert content2.present?

      import.import!
      assert import.status_no_media?
    end

    it "validates timings" do
      assert uncut.present?

      import.timings = "[3abc,1.2]"
      import.import!
      assert import.status_bad_timings?
    end

    it "re-segments uncuts" do
      assert uncut.present?

      Episode.stub_any_instance(:copy_media, true) do
        import.import!
        assert import.status_complete?

        assert_equal [[nil, 1.23], [1.23, 4.56], [4.56, nil]], uncut.reload.segmentation
        assert_equal 3, episode.reload.segment_count
      end
    end

    it "re-segments single contents" do
      assert content1.present?

      Episode.stub_any_instance(:copy_media, true) do
        episode.update!(medium: "audio")

        import.import!
        assert import.status_complete?
        assert content1.reload.deleted_at.present?

        assert episode.uncut.present?
        assert_equal [[nil, 1.23], [1.23, 4.56], [4.56, nil]], episode.uncut.segmentation
        assert_equal 3, episode.reload.segment_count
      end
    end
  end
end
