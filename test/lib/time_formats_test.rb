require 'test_helper'
require 'time_formats'

class Fixnum; include TimeFormats; end
class Bignum; include TimeFormats; end

describe TimeFormats do
  it 'formats 0-23 as a string' do
    0.to_hour_of_day.must_equal '12:00:00 midnight'
    (1..11).each{|h| h.to_hour_of_day.must_equal "#{h}:00:00 AM"}
    12.to_hour_of_day.must_equal '12:00:00 noon'
    (13..23).each{|h| h.to_hour_of_day.must_equal "#{h - 12}:00:00 PM"}
  end

  it 'formats integers to HH:MM:SS' do
    1.to_time_summary.must_equal '0:01'
    100.to_time_summary.must_equal '01:40'
    10000.to_time_summary.must_equal '02:46:40'
    1000000.to_time_summary.must_equal '277:46:40'
  end

  it 'formats integers to time duration sentence' do
    1.to_time_in_words.must_equal '1 second'
    100.to_time_in_words.must_equal '1 minute and 40 seconds'
    10000.to_time_in_words.must_equal '2 hours, 46 minutes, and 40 seconds'
    1000000.to_time_in_words.must_equal '277 hours, 46 minutes, and 40 seconds'
  end
end
