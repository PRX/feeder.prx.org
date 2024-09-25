require "test_helper"

describe Content do
  let(:episode) { create(:episode, contents: [c1, c2, c3]) }
  let(:c1) { build(:content, position: 1) }
  let(:c2) { build(:content, position: 2) }
  let(:c3) { build(:content, position: 3) }

  describe "#validate_episode_medium" do
    it "does not run on incomplete contents" do
      episode.medium = "audio"
      c1.medium = "audio"
      c2.medium = "video"
      c3.medium = "text"

      assert c1.valid?
      assert c2.valid?
      assert c3.valid?
    end

    it "matches content medium to episode medium" do
      c1.status = "complete"

      c1.medium = "audio"
      c1.episode.medium = "audio"
      assert c1.valid?

      c1.episode.medium = "video"
      refute c1.valid?

      c1.medium = "video"
      assert c1.valid?
    end
  end

  describe "#validate_segmentation" do
    it "validates an ordered array of 2 numbers" do
      assert_nil c1.segmentation
      assert c1.valid?

      c1.segmentation = []
      refute c1.valid?

      c1.segmentation = [1.23, 4.56]
      assert c1.valid?

      c1.segmentation = [nil, 4.56]
      assert c1.valid?

      c1.segmentation = [1.23, nil]
      assert c1.valid?

      c1.segmentation = [nil, nil]
      assert c1.valid?

      c1.segmentation = [1.23, 4.56, 7.89]
      refute c1.valid?

      c1.segmentation = [4.56, 1.23]
      refute c1.valid?
    end
  end

  describe "#slice_start / #slice_end" do
    it "gets and sets segmentation" do
      assert_nil c1.slice_start
      assert_nil c1.slice_end
      assert_nil c1.segmentation

      c1.slice_start = 1.23
      assert_equal [1.23, nil], c1.segmentation

      c1.slice_end = 4.56
      assert_equal [1.23, 4.56], c1.segmentation
      assert_equal 1.23, c1.slice_start
      assert_equal 4.56, c1.slice_end

      c1.slice_start = nil
      assert_equal [nil, 4.56], c1.segmentation
    end
  end

  describe "#slice?" do
    it "checks for nil start and end" do
      c1.segmentation = nil
      refute c1.slice?

      c1.segmentation = [nil, nil]
      refute c1.slice?

      c1.segmentation = [nil, 2]
      assert c1.slice?
    end
  end

  describe "#publish_episode!" do
    it "publishes the episode when complete and status has changed" do
      publish = Minitest::Mock.new

      c1.episode.stub(:publish!, publish) do
        c1.update(status: "processing")
        assert publish.verify

        publish.expect(:call, nil)
        c1.update(status: "complete")
        assert publish.verify
      end
    end
  end

  describe "#replace?" do
    it "checks segmentations" do
      assert_equal c1.original_url, c2.original_url
      refute c1.replace?(c2)

      c1.segmentation = [1.23, 4.56]
      assert c1.replace?(c2)

      c2.segmentation = [1.23, 4.56]
      refute c1.replace?(c2)

      # original url changes still need replacement
      c2.original_url = "http://some.where/else.mp3"
      assert c1.replace?(c2)
    end
  end

  describe "#replace_resources!" do
    it "replaces contents with the same position" do
      assert_equal [c1, c2, c3], episode.contents

      c4 = create(:content, episode: episode, position: 2)
      assert_equal [c1, c4, c3], episode.reload.contents

      refute_nil c2.reload.deleted_at
    end
  end
end
