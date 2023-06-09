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

  describe "#publish_episode!" do
    it "publishes the episode when complete and status has changed" do
      publish = MiniTest::Mock.new

      c1.episode.stub(:publish!, publish) do
        c1.update(status: "processing")
        publish.verify

        publish.expect(:call, nil)
        c1.update(status: "complete")
        publish.verify
      end
    end
  end

  describe "#replace_resources!" do
    it "replaces contents with the same position" do
      assert_equal [c1, c2, c3], episode.contents

      c4 = create(:content, episode: episode, position: 2)
      assert_equal [c1, c4, c3], episode.reload.contents

      refute_nil c2.reload.deleted_at
      refute_nil c2.replaced_at
    end
  end
end
