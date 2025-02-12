require "test_helper"
describe Megaphone::Cuepoint do
  let(:episode) { create(:episode) }
  let(:zones) { JSON.parse(json_file(:zones)).map(&:with_indifferent_access) }
  let(:media) {
    [
      create(:content, episode: episode, position: 1, duration: 120.00),
      create(:content, episode: episode, position: 2, duration: 300.00),
      create(:content, episode: episode, position: 3, duration: 120.00)
    ]
  }

  describe "#valid?" do
    it "must have required attributes" do
      cuepoints = Megaphone::Cuepoint.from_zones_and_media(zones, media)
      assert cuepoints.length == 3
      assert cuepoints[0].ad_count == 3
      assert cuepoints[0].ad_sources == [:promo, :auto, :auto]
      assert cuepoints[0].start_time.to_i == 120

      assert cuepoints[1].ad_count == 2
      assert cuepoints[1].ad_sources == [:auto, :auto]
      assert cuepoints[1].start_time.to_i == (120 + 300)

      assert cuepoints[2].ad_count == 4
      assert cuepoints[2].ad_sources == [:auto, :auto, :promo, :promo]
      assert cuepoints[2].start_time.to_i == (120 + 300 + 120)
    end
  end
end
