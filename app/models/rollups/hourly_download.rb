class Rollups::HourlyDownload < ActiveRecord::Base
  establish_connection :clickhouse

  INTERVALS = %i[HOUR DAY WEEK MONTH]
  DROPDAY_OPTIONS = [7, 14, 28, 30, 60, 90, 24, 48]
  PODCAST_DATE_PRESETS = %i[7_days date_week 14_days 28_days 1_month date_month 3_months 6_months 1_year date_year]
end
