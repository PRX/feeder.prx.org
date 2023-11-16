require "test_helper"

describe Uncut do
  let(:uncut) { build_stubbed(:uncut) }

  describe "#cut_contents" do
    let(:episode) { create(:episode, medium: "uncut", segment_count: 3) }
    let(:segs) { [[nil, 1], [2, 3], [3, nil]] }
    let(:uncut) { create(:uncut, episode: episode, status: "complete", segmentation: segs) }

    it "creates new contents" do
      assert_empty episode.contents

      uncut.slice_contents
      assert_equal 3, episode.contents.size
      assert_equal [1, 2, 3], episode.contents.pluck(:position)
      assert_equal [uncut.url], episode.contents.pluck(:original_url).uniq
      assert_equal segs, episode.contents.pluck(:segmentation)
      assert_equal [true, true, true], episode.contents.map(&:changed?)
    end

    it "updates existing contents" do
      uncut.slice_contents!

      uncut.segmentation[0] = [0.5, 1]
      uncut.segmentation[2] = [3.5, nil]
      episode.contents[0].update(status: "complete", medium: "audio")
      uncut.slice_contents

      assert_equal 5, episode.contents.size
      assert_equal [1, 2, 3, 1, 3], episode.contents.pluck(:position)
      assert_equal [uncut.url], episode.contents.pluck(:original_url).uniq
      assert_equal segs + [[0.5, 1], [3.5, nil]], episode.contents.pluck(:segmentation)
      assert_equal [false, false, false, true, true], episode.contents.map(&:changed?)

      # NOTE: since only contents[0] was completed, it's the only one marked replaced
      assert_equal [true, false, false, false, false], episode.contents.map(&:marked_for_replacement?)
      assert_equal [true, false, true, false, false], episode.contents.map(&:marked_for_destruction?)
    end
  end

  describe "#valid?" do
    it "must be audio when complete" do
      assert uncut.valid?
      assert uncut.status_created?

      uncut.medium = "video"
      assert uncut.valid?

      uncut.status = "complete"
      refute uncut.valid?

      uncut.medium = "audio"
      assert uncut.valid?
    end
  end

  describe "#validate_segmentation" do
    it "allows nil" do
      uncut.segmentation = nil
      assert uncut.valid?
    end

    it "checks for arrays of 2 positive numerics" do
      uncut.segmentation = []
      refute uncut.valid?

      uncut.segmentation = [[0, 1]]
      refute uncut.valid?

      uncut.segmentation = [[1, 2.2, 3]]
      refute uncut.valid?

      uncut.segmentation = [[1, "2.2"]]
      refute uncut.valid?

      uncut.segmentation = [[1, 2.2], [3, 4]]
      assert uncut.valid?
    end

    it "allows nils in the first/last segments" do
      uncut.segmentation = [[nil, nil]]
      assert uncut.valid?

      uncut.segmentation = [[1, 2], [nil, 4], [5, 6]]
      refute uncut.valid?

      uncut.segmentation = [[1, nil], [3, 4], [5, 6]]
      refute uncut.valid?

      uncut.segmentation = [[1, 2], [3, 4], [nil, 6]]
      refute uncut.valid?

      uncut.segmentation = [[nil, 2], [3, 4], [5, nil]]
      assert uncut.valid?
    end

    it "checks for an ordered array" do
      uncut.segmentation = [[0.5, 1], [2.2, 3.9999]]
      assert uncut.valid?

      uncut.segmentation = [[nil, 0.5], [1, 2.2], [3, nil]]
      assert uncut.valid?

      uncut.segmentation = [[0.5, 2.2], [1, 3.9999]]
      refute uncut.valid?
    end

    it "requires non-empty segments" do
      uncut.segmentation = [[0.5, 0.5]]
      refute uncut.valid?

      uncut.segmentation = [[0.5, 2.2], [2.2, 2.2]]
      refute uncut.valid?

      uncut.segmentation = [[0.5, 2.2], [2.2, 2.200000001], [2.200000001, 2.3]]
      assert uncut.valid?
    end
  end

  describe "#segmentation_ready?" do
    it "must be status complete" do
      uncut.segmentation = [[1, 2.2]]
      refute uncut.segmentation_ready?

      uncut.status = "complete"
      assert uncut.segmentation_ready?
    end

    it "must be valid" do
      uncut.status = "complete"
      uncut.segmentation = [[1, 2.2]]
      uncut.medium = "video"
      refute uncut.segmentation_ready?
    end

    it "checks the episode segment count" do
      uncut.status = "complete"
      uncut.segmentation = [[1, 2.2], [3, nil]]
      uncut.episode.segment_count = 3
      refute uncut.segmentation_ready?

      uncut.episode.segment_count = 2
      assert uncut.segmentation_ready?

      uncut.episode.segment_count = 1
      refute uncut.segmentation_ready?

      uncut.segmentation = [[nil, nil]]
      assert uncut.segmentation_ready?
    end

    it "checks the uncut duration" do
      uncut.episode.segment_count = 2
      uncut.segmentation = [[1, 2.2], [3.3, nil]]
      uncut.status = "complete"
      assert uncut.segmentation_ready?

      uncut.segmentation = [[1, 2.2], [3.3, 999]]
      refute uncut.segmentation_ready?

      uncut.segmentation = [[1, 2.2], [999, nil]]
      refute uncut.segmentation_ready?

      uncut.duration = 1000
      assert uncut.segmentation_ready?
    end
  end

  describe "#sanitize_segmentation" do
    it "removes out-of-bounds segments" do
      uncut.segmentation = [[nil, 5], [8, 10], [11, 15]]

      uncut.duration = 15.2
      assert_equal uncut.segmentation, uncut.sanitize_segmentation

      uncut.duration = 11.2
      assert_equal [[nil, 5], [8, 10], [11, nil]], uncut.sanitize_segmentation

      uncut.duration = 11
      assert_equal [[nil, 5], [8, 10]], uncut.sanitize_segmentation

      uncut.duration = 9.4
      assert_equal [[nil, 5], [8, nil]], uncut.sanitize_segmentation
    end
  end

  describe "#ad_breaks" do
    it "converts segments to ad breaks" do
      uncut.segmentation = nil
      assert_nil uncut.ad_breaks

      uncut.segmentation = [[nil, 2], [2, nil]]
      assert_equal [2], uncut.ad_breaks

      uncut.segmentation = [[nil, 2], [3, nil]]
      assert_equal [[2, 3]], uncut.ad_breaks

      uncut.segmentation = [[nil, 2], [2, 5], [6, nil]]
      assert_equal [2, [5, 6]], uncut.ad_breaks
    end

    it "handles incompatible segmentation" do
      uncut.segmentation = [[1, 2], [3, 4]]

      # no way to express trimming start/end of segment in this format
      assert_equal [[2, 3]], uncut.ad_breaks
    end
  end

  describe "#ad_breaks=" do
    it "converts ad breaks to segmentations" do
      uncut.ad_breaks = nil
      assert_nil uncut.segmentation

      uncut.ad_breaks = [2]
      assert_equal [[nil, 2], [2, nil]], uncut.segmentation

      uncut.ad_breaks = [[2, 3]]
      assert_equal [[nil, 2], [3, nil]], uncut.segmentation

      uncut.ad_breaks = [[2, 3], 5, 6]
      assert_equal [[nil, 2], [3, 5], [5, 6], [6, nil]], uncut.segmentation

      uncut.ad_breaks = [[2, 3], [5, 6]]
      assert_equal [[nil, 2], [3, 5], [6, nil]], uncut.segmentation
    end
  end
end
