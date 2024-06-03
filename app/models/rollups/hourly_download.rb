class Rollups::HourlyDownload < ActiveRecord::Base
  establish_connection :clickhouse
end
