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

    describe "#add_zone" do
      it "ignores nil" do
        refute_equal feed.include_zones, all_zones
        feed.billboard = ("1")
        refute_equal feed.include_zones, all_zones
      end

      it "adds to include_zones if zone is checked" do
        feed.include_zones = []
        feed.billboard = ("1")
        assert_includes feed.include_zones, "billboard"
        feed.house = ("1")
        assert_includes feed.include_zones, "house"
        feed.paid = ("1")
        assert_includes feed.include_zones, "ad"

        feed.include_zones = []
        feed.sonic_id = ("1")
        assert_includes feed.include_zones, "sonic_id"
      end

      it "does not dupe zones if already checked" do
        feed.include_zones = ["billboard"]
        feed.billboard = "1"
        refute_equal feed.include_zones, ["billboard", "billboard"]
        assert_includes feed.include_zones, "billboard"
      end

      it "nils include_zones if all zones are checked" do
        feed.include_zones = []
        refute_nil feed.include_zones
        feed.billboard = ("1")
        feed.house = ("1")
        feed.paid = ("1")
        feed.sonic_id = ("1")
        assert_nil feed.include_zones
      end
    end

    describe "#remove_zone" do
      it "removes the selected zone" do
        feed.include_zones = all_zones

        assert_includes feed.include_zones, "billboard"
        feed.billboard = "0"
        refute_includes feed.include_zones, "billboard"
      end

      it "leaves an empty array if all zones are de-selected" do
        feed.include_zones = all_zones

        assert_equal feed.include_zones.count, 4

        feed.billboard = "0"
        feed.house = "0"
        feed.paid = "0"
        feed.sonic_id = "0"

        assert_empty feed.include_zones
      end
    end
  end
end
