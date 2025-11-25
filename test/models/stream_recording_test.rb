require "test_helper"

describe StreamRecording do
  let(:stream) { build_stubbed(:stream_recording) }

  describe "#set_defaults" do
    it "sets unchanged defaults" do
      stream = StreamRecording.new
      assert_equal "disabled", stream.status
      refute stream.status_changed?
      assert_equal "clips", stream.create_as
      refute stream.create_as_changed?

      stream = StreamRecording.new(status: "enabled")
      assert_equal "enabled", stream.status
      assert stream.status_changed?
    end
  end

  describe "#record_days" do
    it "validates integer days of week" do
      stream.record_days = [0, 1, 2, 3, 4, 5, 6]
      assert stream.valid?

      stream.record_days = [0, 6]
      assert stream.valid?

      stream.record_days = [-1, 6]
      refute stream.valid?

      stream.record_days = [7]
      refute stream.valid?
    end

    it "handles strings" do
      stream.record_days = ["0", 1, "3"]
      assert_equal [0, 1, 3], stream.record_days

      stream.record_days = "4"
      assert_equal [4], stream.record_days
    end

    it "assumes you want all days if blank" do
      stream.record_days = nil
      assert_equal (0..6).to_a, stream.record_days
      assert_nil stream[:record_days]

      stream.record_days = [""]
      assert_equal (0..6).to_a, stream.record_days
      assert_nil stream[:record_days]

      stream.record_days = 0..6
      assert_equal (0..6).to_a, stream.record_days
      assert_nil stream[:record_days]
    end
  end

  describe "#record_hours" do
    it "validates integer hours of day" do
      stream.record_hours = [0, 10, 22, 23]
      assert stream.valid?

      stream.record_hours = [0, 23]
      assert stream.valid?

      stream.record_hours = [-1, 6]
      refute stream.valid?

      stream.record_hours = [24]
      refute stream.valid?
    end

    it "handles strings" do
      stream.record_hours = ["0", 10, "22"]
      assert_equal [0, 10, 22], stream.record_hours

      stream.record_hours = "4"
      assert_equal [4], stream.record_hours
    end

    it "assumes you want all hours if blank" do
      stream.record_hours = nil
      assert_equal (0..23).to_a, stream.record_hours
      assert_nil stream[:record_hours]

      stream.record_hours = [""]
      assert_equal (0..23).to_a, stream.record_hours
      assert_nil stream[:record_hours]

      stream.record_hours = 0..23
      assert_equal (0..23).to_a, stream.record_hours
      assert_nil stream[:record_hours]
    end
  end
end
