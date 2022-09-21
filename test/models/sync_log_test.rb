# frozen_string_literal: true

require "test_helper"
require "prx_access"

describe SyncLog do
  describe ".feeds" do
    it "filters records by a feeds enum" do
      s = SyncLog.new(feeder_type: :feeds, feeder_id: 123)
      s.save!
      assert_equal SyncLog.feeds, [s]
    end
  end

  describe "#external_type" do
    it "can set an external type" do
      s = SyncLog.new(feeder_type: :episodes, feeder_id: 123, external_type: :podcast_containers, external_id: "1235")
      s.save!

      assert_equal s.persisted?, true
    end
  end
end
