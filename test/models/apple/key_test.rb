require "test_helper"

describe Apple::Config do
  describe "#valid?" do
    it "requires all apple credentials to have a value or be nil" do
      v1 = build(:apple_key, provider_id: nil, key_id: "blood", key_pem_b64: "orange")
      refute v1.valid?

      v2 = build(:apple_key, provider_id: "barlett", key_id: nil, key_pem_b64: "pear")
      refute v2.valid?

      v3 = build(:apple_key, provider_id: "cotton candy", key_id: "grapes", key_pem_b64: nil)
      refute v3.valid?

      v4 = build(:apple_key, provider_id: nil, key_id: nil, key_pem_b64: nil)
      refute v4.valid?
    end

    it "requires the apple provider id to not have an underscore" do
      v1 = build(:apple_key, provider_id: "foo_bar")
      refute v1.valid?
      assert_equal ["cannot contain an underscore"], v1.errors[:provider_id]
    end
  end

  describe "apple_key" do
    it "base64 decodes the apple key" do
      c = Apple::Key.new(key_pem_b64: Base64.encode64("hello"))
      assert_equal c.key_pem, "hello"
    end
  end
end
