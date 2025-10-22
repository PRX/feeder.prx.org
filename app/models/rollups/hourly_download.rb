class Rollups::HourlyDownload < ActiveRecord::Base
  establish_connection :clickhouse

  INTERVALS = %i[HOUR DAY WEEK MONTH]
  DROPDAY_OPTIONS = [7, 14, 28, 30, 60, 90]
  PODCAST_DATE_PRESETS = %i[last_7_days last_14_days last_28_days last_30_days previous_1_month previous_3_months previous_6_months previous_1_year todate_1_week todate_1_month todate_1_year]
  EPISODE_DATE_PRESETS = %i[all_time drop_7_days drop_14_days drop_28_days drop_1_month drop_3_months last_7_days last_14_days last_28_days last_30_days previous_1_month previous_3_months todate_1_week todate_1_month]
end
