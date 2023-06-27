require "test_helper"

class FeedAdZoneTest < ActiveSupport::TestCase
  let(:podcast) { create(:podcast) }
  let(:feed) { podcast.default_feed }

  describe "getter methods" do
    before do
      assert_nil feed.include_zones
    end

    describe "#billboard" do
      it "returns include_zones check value" do
        assert_equal feed.billboard, "1"
        feed.include_zones = []
        assert_equal feed.billboard, "0"
        feed.include_zones << "billboard"
        assert_equal feed.billboard, "1"
      end
    end

    describe "#house" do
      it "returns include_zones check value" do
        assert_equal feed.house, "1"
        feed.include_zones = []
        assert_equal feed.house, "0"
        feed.include_zones << "house"
        assert_equal feed.house, "1"
      end
    end

    describe "#paid" do
      it "returns include_zones check value" do
        assert_equal feed.paid, "1"
        feed.include_zones = []
        assert_equal feed.paid, "0"
        feed.include_zones << "ad"
        assert_equal feed.paid, "1"
      end
    end

    describe "#sonic_id" do
      it "returns include_zones check value" do
        assert_equal feed.sonic_id, "1"
        feed.include_zones = []
        assert_equal feed.sonic_id, "0"
        feed.include_zones << "sonic_id"
        assert_equal feed.sonic_id, "1"
      end
    end
  end

  describe "setter methods" do
    let(:all_zones) { ["billboard", "house", "ad", "sonic_id"] }

    describe "#billboard=" do
      it "ignores nil" do
        assert_nil feed.include_zones
        feed.billboard = "1"
        assert_nil feed.include_zones
      end

      it "adds to include_zones if zone is checked" do
        feed.include_zones = []
        feed.billboard = "1"
        assert_includes feed.include_zones, "billboard"
      end

      it "does not dupe zones if already checked" do
        feed.include_zones = ["billboard"]
        feed.billboard = "1"
        refute_equal feed.include_zones, ["billboard", "billboard"]
        assert_includes feed.include_zones, "billboard"
      end

      it "nils include_zones if all zones are checked" do
        feed.include_zones = ["house", "ad", "sonic_id"]
        feed.billboard = "1"
        assert_nil feed.include_zones
      end

      it "removes the selected zone if unchecked" do
        feed.include_zones = all_zones
        assert_includes feed.include_zones, "billboard"
        feed.billboard = "0"
        refute_includes feed.include_zones, "billboard"
      end

      it "leaves an empty array if all zones are de-selected" do
        feed.include_zones = ["billboard"]
        feed.billboard = "0"
        refute_nil feed.include_zones
        assert_empty feed.include_zones
      end
    end

    describe "#house=" do
      it "ignores nil" do
        assert_nil feed.include_zones
        feed.house = "1"
        assert_nil feed.include_zones
      end

      it "adds to include_zones if zone is checked" do
        feed.include_zones = []
        feed.house = "1"
        assert_includes feed.include_zones, "house"
      end

      it "does not dupe zones if already checked" do
        feed.include_zones = ["house"]
        feed.house = "1"
        refute_equal feed.include_zones, ["house", "house"]
        assert_includes feed.include_zones, "house"
      end

      it "nils include_zones if all zones are checked" do
        feed.include_zones = ["billboard", "ad", "sonic_id"]
        feed.house = "1"
        assert_nil feed.include_zones
      end

      it "removes the selected zone if unchecked" do
        feed.include_zones = all_zones
        assert_includes feed.include_zones, "house"
        feed.house = "0"
        refute_includes feed.include_zones, "house"
      end

      it "leaves an empty array if all zones are de-selected" do
        feed.include_zones = ["house"]
        feed.house = "0"
        refute_nil feed.include_zones
        assert_empty feed.include_zones
      end
    end

    describe "#paid=" do
      it "ignores nil" do
        assert_nil feed.include_zones
        feed.paid = "1"
        assert_nil feed.include_zones
      end

      it "adds to include_zones if zone is checked" do
        feed.include_zones = []
        feed.paid = "1"
        assert_includes feed.include_zones, "ad"
      end

      it "does not dupe zones if already checked" do
        feed.include_zones = ["ad"]
        feed.paid = "1"
        refute_equal feed.include_zones, ["ad", "ad"]
        assert_includes feed.include_zones, "ad"
      end

      it "nils include_zones if all zones are checked" do
        feed.include_zones = ["billboard", "house", "sonic_id"]
        feed.paid = "1"
        assert_nil feed.include_zones
      end

      it "removes the selected zone if unchecked" do
        feed.include_zones = all_zones
        assert_includes feed.include_zones, "ad"
        feed.paid = "0"
        refute_includes feed.include_zones, "ad"
      end

      it "leaves an empty array if all zones are de-selected" do
        feed.include_zones = ["ad"]
        feed.paid = "0"
        refute_nil feed.include_zones
        assert_empty feed.include_zones
      end
    end

    describe "#sonic_id=" do
      it "ignores nil" do
        assert_nil feed.include_zones
        feed.sonic_id = "1"
        assert_nil feed.include_zones
      end

      it "adds to include_zones if zone is checked" do
        feed.include_zones = []
        feed.sonic_id = "1"
        assert_includes feed.include_zones, "sonic_id"
      end

      it "does not dupe zones if already checked" do
        feed.include_zones = ["sonic_id"]
        feed.sonic_id = "1"
        refute_equal feed.include_zones, ["sonic_id", "sonic_id"]
        assert_includes feed.include_zones, "sonic_id"
      end

      it "nils include_zones if all zones are checked" do
        feed.include_zones = ["billboard", "house", "ad"]
        feed.sonic_id = "1"
        assert_nil feed.include_zones
      end

      it "removes the selected zone if unchecked" do
        feed.include_zones = all_zones
        assert_includes feed.include_zones, "sonic_id"
        feed.sonic_id = "0"
        refute_includes feed.include_zones, "sonic_id"
      end

      it "leaves an empty array if all zones are de-selected" do
        feed.include_zones = ["sonic_id"]
        feed.sonic_id = "0"
        refute_nil feed.include_zones
        assert_empty feed.include_zones
      end
    end
  end
end
