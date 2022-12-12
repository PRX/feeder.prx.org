require "test_helper"

describe AppleCredential do
  describe "#valid?" do
    it "requires both a public and private feed" do
      pub_f = create(:feed)
      priv_f = create(:feed)

      c1 = build(:apple_credential, public_feed: pub_f, private_feed: priv_f)
      assert c1.valid?

      c2 = build(:apple_credential, public_feed: nil, private_feed: priv_f)
      refute c2.valid?

      c3 = build(:apple_credential, public_feed: pub_f, private_feed: nil)
      refute c3.valid?
    end

    it "requires apple key fields" do
      pub = create(:feed, private: false)
      priv = create(:feed, private: true)
      c = build(:apple_credential, public_feed: pub, private_feed: priv)
      assert c.valid?

      c.apple_key_id = nil
      refute c.valid?

      c.apple_key_id = "pears are better"
      c.apple_key_pem_b64 = nil
      refute c.valid?
    end

    it "is unique to a public and private feed" do
      f1 = create(:feed)
      f2 = create(:feed)
      f3 = create(:feed)
      f4 = create(:feed)

      c1 = create(:apple_credential, public_feed: f1, private_feed: f2)
      assert c1.valid?

      c2 = build(:apple_credential, public_feed: f1, private_feed: f2)
      refute c2.valid?

      c3 = build(:apple_credential, public_feed: f1, private_feed: f3)
      assert c3.valid?

      c4 = build(:apple_credential, public_feed: f4, private_feed: f2)
      assert c4.valid?

      c5 = build(:apple_credential, public_feed: f1, private_feed: f1)
      refute c5.valid?
    end
  end

  describe "apple_key" do
    it "base64 decodes the apple key" do
      c = AppleCredential.new(apple_key_pem_b64: Base64.encode64("hello"))
      assert_equal c.apple_key, "hello"
    end
  end
end
