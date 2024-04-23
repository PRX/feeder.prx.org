require "active_support/concern"

module TimeRollups
  extend ActiveSupport::Concern

  included do
    scope :rollup_zone, ->(name) do
      if defined?(@rollup_part)
        raise "rollup_time_zone must be called before rollup_time"
      elsif !class_variable_get(:@@rollup_zone_supported)
        raise "time zone not supported for: #{class_variable_get(:@@rollup_time_col)}"
      end

      @rollup_zone = name

      all
    end

    scope :rollup_time, ->(date_part, facets = []) do
      @rollup_part = date_part

      select_time = rollup_select_time(@rollup_part, @rollup_zone)
      selects = (facets + [select_time, rollup_select_count]).compact
      groups = (facets + [select_time]).compact

      # extend .order() so we can sort by the rollup columns
      select(selects).group(groups).extending do
        def order(*args)
          new_args = args.map do |arg|
            if arg.is_a?(Hash)
              arg.map do |key, val|
                if key.to_s == class_variable_get(:@@rollup_time_col).to_s
                  [Arel.sql(rollup_select_time(@rollup_part, @rollup_zone)), val]
                elsif key.to_s == class_variable_get(:@@rollup_count_col).to_s
                  [Arel.sql(rollup_select_count), val]
                else
                  [key, val]
                end
              end.to_h
            else
              arg
            end
          end

          super(*new_args)
        end
      end
    end

    scope :rollup_hour, ->(*facets) { rollup_time("day", facets) }
    scope :rollup_day, ->(*facets) { rollup_time("day", facets) }
    scope :rollup_week, ->(*facets) { rollup_time("week", facets) }
    scope :rollup_month, ->(*facets) { rollup_time("month", facets) }
    scope :rollup_year, ->(*facets) { rollup_time("year", facets) }
    scope :rollup_total, ->(*facets) { rollup_time(nil, facets) }

    def self.time_rollups(time_col, count_col, zone_supported = false)
      class_variable_set(:@@rollup_time_col, time_col)
      class_variable_set(:@@rollup_count_col, count_col)
      class_variable_set(:@@rollup_zone_supported, zone_supported)
    end

    protected

    def self.rollup_select_time(part, zone)
      if part
        unless %w[hour day week month year].include?(part.to_s)
          raise "invalid rollup date part: #{part}"
        end

        time = class_variable_get(:@@rollup_time_col)
        if zone.present? && zone != "UTC"
          "DATE_TRUNC('#{part}', #{time}, '#{zone}') AS #{time}"
        else
          "DATE_TRUNC('#{part}', #{time}) AS #{time}"
        end
      end
    end

    def self.rollup_select_count
      count = class_variable_get(:@@rollup_count_col)
      "SUM(#{count}) AS #{count}"
    end
  end
end
