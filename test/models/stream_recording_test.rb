require "test_helper"

describe StreamRecording do
  let(:stream) { build_stubbed(:stream_recording) }

  describe ".config" do
    it "generates configuration json for active streams" do
      s1 = create(:stream_recording, record_days: nil, record_hours: nil)
      s2 = create(:stream_recording, start_date: 7.days.from_now)
      create(:stream_recording, status: "paused")
      create(:stream_recording, end_date: 2.days.ago)

      config = StreamRecording.config
      assert_equal 2, config.count
      assert_equal [s1.id, s2.id].sort, config.pluck(:id).sort
      assert_equal [PorterUtils.callback_sqs], config.pluck(:callback).uniq
    end
  end

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
      stream.record_days = ["1", "4", 2]
      assert_equal [1, 2, 4], stream.record_days

      stream.record_days = "5"
      assert_equal [5], stream.record_days
    end

    it "sets to nil if you want all days" do
      stream.record_days = nil
      assert_nil stream.record_days

      stream.record_days = [""]
      assert_nil stream.record_days

      stream.record_days = 0..6
      assert_nil stream.record_days

      stream.record_days = (0..6).to_a.shuffle
      assert_nil stream.record_days
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
      stream.record_hours = ["0", "22", 10]
      assert_equal [0, 10, 22], stream.record_hours

      stream.record_hours = "4"
      assert_equal [4], stream.record_hours
    end

    it "sets to nil if you want all hours" do
      stream.record_hours = nil
      assert_nil stream.record_hours

      stream.record_hours = [""]
      assert_nil stream.record_hours

      stream.record_hours = 0..23
      assert_nil stream.record_hours

      stream.record_hours = (0..23).to_a.shuffle
      assert_nil stream.record_hours
    end
  end
end
