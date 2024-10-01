require "test_helper"

describe Megaphone::Config do
  describe "#valid?" do
    it "must have required attributes" do
      config = build(:megaphone_config, feed_id: 123)
      assert_not_nil config.token
      assert_not_nil config.network_id
      assert_not_nil config.feed_id
      assert config.valid?
    end
  end
end
