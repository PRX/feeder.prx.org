require "test_helper"

describe FeederLogger do
  it "times an info block and logs the elapsed seconds" do
    logs = capture_json_logs do
      Rails.logger.elapsed("did a thing") { :result }
    end

    log = logs.find { |l| l["msg"] == "did a thing" }
    assert log.present?
    assert_equal 30, log["level"]
    assert_kind_of Float, log["elapsed"]
    assert_operator log["elapsed"], :>=, 0
  end

  it "times a debug block and logs the elapsed seconds" do
    logs = capture_json_logs do
      Rails.logger.debug_elapsed("did a quiet thing") { :result }
    end

    log = logs.find { |l| l["msg"] == "did a quiet thing" }
    assert log.present?
    assert_equal 20, log["level"]
    assert_kind_of Float, log["elapsed"]
  end

  it "yields the block and returns what the log call returns" do
    called = false
    capture_json_logs do
      Rails.logger.elapsed("ran") { called = true }
    end

    assert called, "expected the block to be called"
  end

  it "merges extra args into the log entry" do
    logs = capture_json_logs do
      Rails.logger.elapsed("with args", {podcast_id: 42}) { :ok }
    end

    log = logs.find { |l| l["msg"] == "with args" }
    assert log.present?
    assert_equal 42, log["podcast_id"]
    assert_kind_of Float, log["elapsed"]
  end

  it "accepts a hash instead of a message" do
    logs = capture_json_logs do
      Rails.logger.elapsed({msg: "hash form", episode_id: 7}) { :ok }
    end

    log = logs.find { |l| l["msg"] == "hash form" }
    assert log.present?
    assert_equal 7, log["episode_id"]
    assert_kind_of Float, log["elapsed"]
  end

  it "reports time that actually elapsed" do
    logs = capture_json_logs do
      Rails.logger.elapsed("slow thing") { sleep 0.01 }
    end

    log = logs.find { |l| l["msg"] == "slow thing" }
    assert_operator log["elapsed"], :>=, 0.01
  end
end
