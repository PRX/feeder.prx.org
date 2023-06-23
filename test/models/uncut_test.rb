require "test_helper"

describe Uncut do
  let(:uncut) { build_stubbed(:uncut) }

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
