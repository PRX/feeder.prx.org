class Rollups::HourlyDownload < ActiveRecord::Base
  establish_connection :clickhouse

  INTERVALS = %i[HOUR DAY WEEK MONTH]
  DROPDAY_OPTIONS = [7, 14, 28, 30, 60, 90]
  PODCAST_DATE_PRESETS = %i[7_days_last 14_days_last 28_days_last 1_month_previous 3_months_previous 6_months_previous 1_year_previous date_week date_month date_year]
  EPISODE_DATE_PRESETS = %i[all_time 7_days_drop 14_days_drop 28_days_drop 1_month_drop 3_months_drop 7_days_last 14_days_last 28_days_last 1_month_previous 3_months_previous date_week date_month]
end
