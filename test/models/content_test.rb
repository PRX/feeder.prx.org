require "test_helper"

describe Content do
  let(:episode) { create(:episode, contents: [c1, c2, c3]) }
  let(:c1) { build(:content, position: 1) }
  let(:c2) { build(:content, position: 2) }
  let(:c3) { build(:content, position: 3) }

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
