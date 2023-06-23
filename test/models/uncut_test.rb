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

    it "checks for an array of positive numerics" do
      uncut.segmentation = []
      assert uncut.valid?

      uncut.segmentation = [0.5, 1, 2.2, 3.9999]
      assert uncut.valid?

      uncut.segmentation = [0.5, 1, 2.2, "3"]
      refute uncut.valid?

      uncut.segmentation = [-1, 0.5, 1, 2.2]
      refute uncut.valid?

      uncut.segmentation = [0, 1, 2.2]
      refute uncut.valid?
    end

    it "allows segment arrays of 2 positive numerics" do
      uncut.segmentation = [[0.5, 1], 2.2, 3.9999]
      assert uncut.valid?

      uncut.segmentation = [[0.5, 1], [2.2], 3.9999]
      refute uncut.valid?

      uncut.segmentation = [[0.5, 1, 2.2], 3.9999]
      refute uncut.valid?

      uncut.segmentation = [[0.5, "1"], 2.2, 3.9999]
      refute uncut.valid?

      uncut.segmentation = [[-1, 1], 2.2, 3.9999]
      refute uncut.valid?
    end

    it "checks for an ordered array" do
      uncut.segmentation = [0.5, 1, 2.2, 3.9999]
      assert uncut.valid?

      uncut.segmentation = [0.5, [1, 2.2], 3.9999]
      assert uncut.valid?

      uncut.segmentation = [0.5, 2.2, 1, 3.9999]
      refute uncut.valid?

      uncut.segmentation = [0.5, [1, 3.9999], 2.2]
      refute uncut.valid?
    end

    it "allows slicing the beginning/end of the file using a nil range" do
      uncut.segmentation = [0, 4]
      refute uncut.valid?

      uncut.segmentation = [nil, 4]
      refute uncut.valid?

      uncut.segmentation = [[1, nil], 4]
      refute uncut.valid?

      uncut.segmentation = [[nil, 1], 4]
      assert uncut.valid?

      uncut.segmentation = [[nil, 1], 4, [5, nil]]
      assert uncut.valid?
    end
  end
end
