class Rollups::DailyGeo < ActiveRecord::Base
  establish_connection :clickhouse

  def self.label_for(country_code)
    ISO3166::Country[country_code]&.iso_short_name || "Other"
  end
end
