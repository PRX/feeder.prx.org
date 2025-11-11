require "test_helper"

class TestMetadataBreaks
  include MetadataBreaks
end

describe TestMetadataBreaks do
  let(:metadata_breaks) { TestMetadataBreaks.new }

  describe "#breaks_from_tags" do
    it "extracts breaks from tags" do
      tags = [
        {key: "comment", value: "PREROLL_1;AIS_AD_BREAK_1=491677,0;"},
        {key: "custom", value: "AIS_AD_BREAK_2=30000;AIS_AD_BREAK_POST=300000;trash=none;AIS_AD_BREAK_3=30000"}
      ]
      result = metadata_breaks.breaks_from_tags(tags)
      assert_equal [30.0, 300.0, 491.677], result
    end

    it "handles invalid tags" do
      tags = [
        {key: "comment", value: "PREROLL_1;AIS_AD_BREAK_1=boo;AIS_AD_BREAK_2=boo,0;AIS_AD_BREAK_3=1000,boo"},
        {key: "custom", value: "AIS_AD_BREAK_3=30000"}
      ]
      result = metadata_breaks.breaks_from_tags(tags)
      assert_equal [1.0, 30.0], result
    end
  end

  describe "#parse_break" do
    it "parses break with start and duration" do
      result = metadata_breaks.parse_break("0,30000")
      assert_equal [0.0, 30.0], result

      result = metadata_breaks.parse_break("00:10:00:000,30000")
      assert_equal [600.0, 630.0], result

      result = metadata_breaks.parse_break("15000,45000")
      assert_equal [15.0, 60.0], result
    end

    it "parses break with start and 0 or nil duration" do
      result = metadata_breaks.parse_break("00:10:00:000,0")
      assert_equal 600.0, result

      result = metadata_breaks.parse_break("00:10:00:000,")
      assert_equal 600.0, result
    end

    it "parses break with only start time" do
      result = metadata_breaks.parse_break("00:05:00:000")
      assert_equal 300.0, result

      result = metadata_breaks.parse_break("20000")
      assert_equal 20.0, result
    end
  end

  describe "#parse_break_time" do
    it "parse breaks with integer milliseconds" do
      result = metadata_breaks.parse_break_time("1000")
      assert_equal 1.0, result

      result = metadata_breaks.parse_break_time("1234")
      assert_equal 1.234, result
    end

    it "parse breaks with hh:mm:ss:ms format" do
      result = metadata_breaks.parse_break_time("01:02:03:400")
      assert_equal 3723.4, result
    end

    it "parse incomplete timestamp" do
      result = metadata_breaks.parse_break_time("01:02:03")
      assert_equal 3723.0, result
    end

    it "parse for bad value returns nil" do
      result = metadata_breaks.parse_break_time("bad_value")
      assert_nil result
    end
  end
end
