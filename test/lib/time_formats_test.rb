require "test_helper"
require "time_formats"

describe TimeFormats do
  it "formats 0-23 as a string" do
    assert_equal 0.to_hour_of_day, "12:00:00 midnight"
    (1..11).each { |h| assert_equal(h.to_hour_of_day, "#{h}:00:00 AM") }
    assert_equal 12.to_hour_of_day, "12:00:00 noon"
    (13..23).each { |h| assert_equal(h.to_hour_of_day, "#{h - 12}:00:00 PM") }
  end

  it "formats integers to HH:MM:SS" do
    assert_equal 1.to_time_summary, "0:01"
    assert_equal 100.to_time_summary, "01:40"
    assert_equal 10000.to_time_summary, "02:46:40"
    assert_equal 1000000.to_time_summary, "277:46:40"
  end

  it "formats integers to time duration sentence" do
    assert_equal 1.to_time_in_words, "1 second"
    assert_equal 100.to_time_in_words, "1 minute and 40 seconds"
    assert_equal 10000.to_time_in_words, "2 hours, 46 minutes, and 40 seconds"
    assert_equal 1000000.to_time_in_words, "277 hours, 46 minutes, and 40 seconds"
  end
end
