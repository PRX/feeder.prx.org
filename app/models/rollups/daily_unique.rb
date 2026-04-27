class Rollups::DailyUnique < ActiveRecord::Base
  establish_connection :clickhouse
end
