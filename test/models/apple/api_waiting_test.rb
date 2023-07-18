# frozen_string_literal: true

require "test_helper"

class TestWait
  include Apple::ApiWaiting
  API_WAIT_INTERVAL = 0.seconds
end

class TestTimeout
  include Apple::ApiWaiting
  API_WAIT_INTERVAL = 0.seconds
  API_WAIT_TIMEOUT = 0.seconds
end

describe Apple::ApiWaiting do
  describe ".wait_for" do
    it "waits until there is nothing left to process" do
      records = [1, 2, 3].freeze
      intervals = [
        [1, 2, 3],
        [2, 3],
        [3]
      ]

      step = 0

      (timed_out, remaining) = TestWait.wait_for(records) do |remaining|
        rem = remaining.dup

        assert_equal intervals[step], rem
        step += 1

        # peal off one record at a time
        rem.shift
        # We are still waiting for these:
        rem
      end

      assert_equal timed_out, false
      assert_equal remaining, []
    end

    it "times out" do
      (timed_out, remaining) = TestTimeout.wait_for(["a", "b", "c"]) do |remaining|
        remaining
      end
      binding.pry

      assert_equal timed_out, true
      assert_equal remaining, ["a", "b", "c"]
    end
  end
end
