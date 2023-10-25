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
      podcast = create(:podcast)
      f1 = create(:feed, podcast: podcast)
      f2 = create(:feed, podcast: podcast)
      f3 = create(:feed, podcast: podcast)
      f4 = create(:feed, podcast: podcast)

      c1 = create(:apple_config, podcast: podcast, public_feed: f1, private_feed: f2)
      assert c1.valid?

      c2 = build(:apple_config, podcast: podcast, public_feed: f1, private_feed: f2)
      refute c2.valid?

      c3 = build(:apple_config, podcast: podcast, public_feed: f1, private_feed: f3)
      assert c3.valid?

      c4 = build(:apple_config, podcast: podcast, public_feed: f4, private_feed: f2)
      assert c4.valid?

      c5 = build(:apple_config, podcast: podcast, public_feed: f1, private_feed: f1)
      refute c5.valid?
    end

    it "is unique to a podcast" do
      podcast = create(:podcast)
      f1 = create(:feed, podcast: podcast)
      f2 = create(:feed, podcast: podcast)
      f3 = create(:feed, podcast: podcast)
      f4 = create(:feed, podcast: podcast)

      c1 = create(:apple_config, podcast: podcast, public_feed: f1, private_feed: f2)
      assert c1.valid?

      c2 = build(:apple_config, podcast: podcast, public_feed: f3, private_feed: f4)
      refute c2.valid?
      assert_equal ["has already been taken"], c2.errors[:podcast]
    end
  end
end
