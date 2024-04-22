require "active_support/concern"

module TimeRollups
  extend ActiveSupport::Concern

  included do
    scope :rollup_time, ->(date_part, facets = []) do
      if date_part && %w[hour day week month year].exclude?(date_part.to_s)
        raise "invalid date part: #{date_part}"
      end

      time = @@rollup_time_col
      zone = @@rollup_zone_attr && try(@@rollup_zone_attr) || "UTC"
      select_time = "DATE_TRUNC('#{date_part}', #{time}, '#{zone}') AS #{time}" if date_part
      select_count = "SUM(#{@@rollup_count_col}) AS #{@@rollup_count_col}"
      selects = (facets + [select_time, select_count]).compact
      groups = (facets + [select_time]).compact

      select(selects).group(groups)
    end

    scope :rollup_hour, ->(*facets) { rollup_time("day", facets) }
    scope :rollup_day, ->(*facets) { rollup_time("day", facets) }
    scope :rollup_week, ->(*facets) { rollup_time("week", facets) }
    scope :rollup_month, ->(*facets) { rollup_time("month", facets) }
    scope :rollup_year, ->(*facets) { rollup_time("year", facets) }
    scope :rollup_total, ->(*facets) { rollup_time(nil, facets) }

    def self.time_rollups(time_col, count_col, zone_attr = nil)
      @@rollup_time_col = time_col
      @@rollup_count_col = count_col
      @@rollup_zone_attr = zone_attr
    end
  end
end
