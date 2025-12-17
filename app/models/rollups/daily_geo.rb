class Rollups::DailyGeo < ActiveRecord::Base
  establish_connection :clickhouse

  def country
    ISO3166::Country[country_code] || "Other"
  end

  def country_label
    if country_code == "Other"
      "Other"
    else
      country.iso_short_name
    end
  end
end
