require "test_helper"

describe SubscribeLink do
  let(:podcast) { create(:podcast) }
  let(:apple_link) { SubscribeLink.create(platform: "apple", podcast: podcast, external_id: "12345") }

  describe "#valid?" do
    it "requires a currently supported platform" do
      assert apple_link.valid?
      apple_link.platform = "wnyc"
      refute apple_link.valid?
      apple_link.platform = nil
      refute apple_link.valid?
    end

    it "requires an external id" do
      assert apple_link.valid?
      apple_link.external_id = nil
      refute apple_link.valid?
    end
  end
end
