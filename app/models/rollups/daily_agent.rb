class Rollups::DailyAgent < ActiveRecord::Base
  include TimeRollups

  establish_connection :clickhouse
  time_rollups :day, :count
end
