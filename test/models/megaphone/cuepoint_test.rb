require "test_helper"
describe Megaphone::Cuepoint do
  let(:episode) { create(:episode) }
  let(:zones) { JSON.parse(json_file(:zones)).map(&:with_indifferent_access) }
  let(:sections) { JSON.parse(json_file(:sections)).map(&:with_indifferent_access) }
  let(:placement_struct) { Struct.new("Placement", :sections, :zones) }
  let(:placement) { placement_struct.new(zones: zones, sections: sections) }
  let(:media) {
    [
      create(:content, episode: episode, position: 1, duration: 120.00),
      create(:content, episode: episode, position: 2, duration: 300.00),
      create(:content, episode: episode, position: 3, duration: 120.00)
    ]
  }

  describe "#valid?" do
    it "must have required attributes" do
      cuepoints = Megaphone::Cuepoint.from_placement_and_media(placement, media)
      assert_equal 3, cuepoints.length
      assert_equal 3, cuepoints[0].ad_count
      assert_equal [:promo, :auto, :auto], cuepoints[0].ad_sources
      assert_equal 120, cuepoints[0].start_time.to_i
      assert_nil cuepoints[0].max_duration

      assert_equal 2, cuepoints[1].ad_count
      assert_equal [:auto, :auto], cuepoints[1].ad_sources
      assert_equal (120 + 300), cuepoints[1].start_time.to_i
      assert_equal 90, cuepoints[1].max_duration

      assert_equal 4, cuepoints[2].ad_count
      assert_equal [:auto, :auto, :promo, :promo], cuepoints[2].ad_sources
      assert_equal (120 + 300 + 120), cuepoints[2].start_time.to_i
      assert_nil cuepoints[2].max_duration
    end
  end
end
