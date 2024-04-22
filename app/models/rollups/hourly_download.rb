class Rollups::HourlyDownload < ActiveRecord::Base
  include TimeRollups

  establish_connection :clickhouse
  time_rollups :hour, :count, true
end
