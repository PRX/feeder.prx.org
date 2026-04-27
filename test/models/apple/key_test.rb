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

    describe ".provider_id" do
      it "requires the provider id to be a minimum of 10 characters" do
        v1 = build(:apple_key, provider_id: "foobar")
        refute v1.valid?
        v2 = build(:apple_key, provider_id: "foobarfoobaz")
        assert v2.valid?
      end

      it "requires the apple provider id to not have an underscore" do
        v1 = build(:apple_key, provider_id: "foo_bar")
        refute v1.valid?
        assert_includes v1.errors[:provider_id], "cannot contain an underscore"
      end
    end

    describe ".key_id" do
      it "requires the key id to be a minimum of 10 characters" do
        v1 = build(:apple_key, key_id: "foobar")
        refute v1.valid?
        v2 = build(:apple_key, key_id: "foobarfoobaz")
        assert v2.valid?
      end
    end
  end

  describe "apple_key" do
    it "base64 decodes the apple key" do
      c = Apple::Key.new(key_pem_b64: Base64.encode64("hello"))
      assert_equal c.key_pem, "hello"
    end

    it "encrypts the base64 key at rest" do
      key_pem_b64 = Base64.encode64(test_file("/fixtures/apple_podcasts_connect_keyfile.pem"))
      key = create(:apple_key, key_pem_b64: key_pem_b64)

      raw_key_pem_b64 = Apple::Key.connection.select_value(
        "SELECT key_pem_b64 FROM apple_keys WHERE id = #{key.id}"
      )

      refute_equal key_pem_b64, raw_key_pem_b64
      assert Apple::Key.type_for_attribute("key_pem_b64").encrypted?(raw_key_pem_b64)
      assert_equal key_pem_b64, key.reload.key_pem_b64
      assert_equal test_file("/fixtures/apple_podcasts_connect_keyfile.pem"), key.key_pem
    end

    it "builds an api from a key with encrypted pem data" do
      key = create(:apple_key)
      api = Apple::Api.from_key(key.reload)

      assert_equal key.provider_id, api.provider_id
      assert_equal key.key_id, api.key_id
      assert_equal key.key_pem, api.key
    end

    it "requires correct format of apple key" do
      k1 = build(:apple_key)
      k2 = build(:apple_key, key_pem_b64: Base64.encode64("not a valid pem"))

      assert k1.valid?
      refute k2.valid?
    end
  end
end
