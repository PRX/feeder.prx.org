class Rollups::DailyGeo < ActiveRecord::Base
  establish_connection :clickhouse
end
