# frozen_string_literal: true

require "test_helper"

class Test
  include Apple::ApiWaiting
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

      (timed_out, remaining) = Test.wait_for(records, wait_interval: 0.seconds) do |remaining|
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
      (timed_out, remaining) = Test.wait_for(["a", "b", "c"], wait_interval: 0.seconds, wait_timeout: 0.seconds) do |remaining|
        remaining
      end

      assert_equal timed_out, true
      assert_equal remaining, ["a", "b", "c"]
    end

    it "times out by default after 5 minutes" do
      current_time = Time.utc(2021, 1, 1, 0, 0, 0)
      index = 0

      Test.stub(:current_time, -> {
                                 current_time += index.minutes
                                 index += 1
                               }) do
        (timed_out, remaining) = Test.wait_for(["a", "b", "c"], wait_interval: 0.seconds) do |remaining|
          remaining
        end

        assert_equal timed_out, true
        assert_equal remaining, ["a", "b", "c"]
      end
    end
  end
end
