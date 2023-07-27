require "test_helper"

describe Apple::Config do
  describe "#valid?" do
    it "requires both a public and private feed" do
      pub_f = create(:feed)
      priv_f = create(:feed)

      c1 = build(:apple_config, public_feed: pub_f, private_feed: priv_f)
      assert c1.valid?

      c2 = build(:apple_config, public_feed: nil, private_feed: priv_f)
      refute c2.valid?

      c3 = build(:apple_config, public_feed: pub_f, private_feed: nil)
      refute c3.valid?
    end

    it "is unique to a public and private feed" do
      f1 = create(:feed)
      f2 = create(:feed)
      f3 = create(:feed)
      f4 = create(:feed)

      c1 = create(:apple_config, public_feed: f1, private_feed: f2)
      assert c1.valid?

      c2 = build(:apple_config, public_feed: f1, private_feed: f2)
      refute c2.valid?

      c3 = build(:apple_config, public_feed: f1, private_feed: f3)
      assert c3.valid?

      c4 = build(:apple_config, public_feed: f4, private_feed: f2)
      assert c4.valid?

      c5 = build(:apple_config, public_feed: f1, private_feed: f1)
      refute c5.valid?
    end
  end
end
