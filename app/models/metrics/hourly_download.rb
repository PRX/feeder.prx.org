class Metrics::HourlyDownload < ActiveRecord::Base
  include TimeRollups

  establish_connection :clickhouse
  time_rollups :hour, :count, :rollup_zone

  def self.rollup_zone(*args)
    if args.empty?
      @@rollup_zone if defined?(@@rollup_zone)
    else
      @@rollup_zone = args.first
      self
    end
  end

  def self.rollup_zone=(name)
    @@rollup_zone = name
  end

  def hour
    time = super

    if time.present? && self.class.rollup_zone.present?
      time.change(zone: self.class.rollup_zone)
    else
      time
    end
  end
end
