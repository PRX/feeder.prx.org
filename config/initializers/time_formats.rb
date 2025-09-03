require "time_formats"

class Numeric
  include TimeFormats
end

class Date
  def self.utc_today
    Time.zone.now.utc.to_date
  end

  def self.utc_yesterday
    Time.zone.now.utc.to_date - 1.day
  end
end
