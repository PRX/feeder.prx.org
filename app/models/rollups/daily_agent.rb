class Rollups::DailyAgent < ActiveRecord::Base
  establish_connection :clickhouse
end
