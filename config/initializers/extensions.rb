require "time_formats"

class Numeric
  include TimeFormats
end

class Date
  def self.utc_yesterday
    utc_today - 1
  end

  def self.utc_today
    Time.now.utc.to_date
  end

  def self.utc_tomorrow
    utc_today + 1
  end
end

class ActiveSupport::TimeWithZone
  def utc_date
    utc.to_date
  end
end

class Array
  def to_enum_h
    map { |v| [v, v] }.to_h
  end

  def with_indifferent_access
    map { |v| v.try(:with_indifferent_access) || v }
  end
end
