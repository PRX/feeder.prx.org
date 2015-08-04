# helper and mixin methods to format strings from integers representing duration
module TimeFormats

  # turns an integer from 0-23 into an hour of the day
  # e.g.  4.to_hour_of_day -> '4:00:00 AM'
  #      14.to_hour_of_day -> '2:00:00 PM'
  def to_hour_of_day
    h = self.to_i
    if h == 0
      '12:00:00 midnight'
    elsif h > 0 && h < 12
      "#{h}:00:00 AM"
    elsif h == 12
      '12:00:00 noon'
    elsif h > 12 && h < 24
      "#{h-12}:00:00 PM"
    end
  end

  # turns an integer into a string with HH:MM:SS format
  # e.g. 100.to_time_summary -> '1:40'
  def to_time_summary
    time_duration_summary(self)
  end

  # turns an integer into a sentence for the duration
  # e.g. 100.to_time_in_words -> '1 minute and 40 seconds'
  def to_time_in_words
    time_duration_in_words(self)
  end

  def time_duration_in_words(seconds=0)
    return '0 seconds' if seconds <= 0
    time_values = time_duration(seconds)
    [:hour, :minute, :second].inject([]) { |words, unit|
      if (time_values[unit] > 0)
        units_text = (time_values[unit] == 1) ? unit.to_s : unit.to_s.pluralize
        words << "#{time_values[unit]} #{units_text}"
      end
      words
    }.to_sentence
  end

  def time_duration_summary(seconds=0)
    return ':00' if seconds <= 0
    time_values = time_duration(seconds)
    last_zero = true
    nums = [:hour, :minute, :second].collect do |unit|
      if last_zero && (time_values[unit] == 0)
        nil
      else
        last_zero = false
        format("%02d", time_values[unit])
      end
    end.compact
    if nums.size > 1
      nums.join(':')
    else
      ":#{nums[0]}"
    end
  end

  def time_duration(seconds)
    return {:second=>0} if seconds <= 0
    secs = seconds
    [[:hour,3600], [:minute,60], [:second,1]].inject({}) do |values, each|
      unit,size = each
      values[unit] = ((secs <= 0) ? 0 : (secs / size))
      secs = ((secs <= 0) ? 0 : (secs % size))
      values
    end
  end
end
