class Rollups::DailyUnique < ActiveRecord::Base
  establish_connection :clickhouse

  UNIQUE_OPTIONS = %i[last_7_rolling last_28_rolling calendar_week calendar_month]
end
