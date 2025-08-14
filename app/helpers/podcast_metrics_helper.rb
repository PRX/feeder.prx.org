module PodcastMetricsHelper
  def parse_agent_data(agents)
    agents.map do |a|
      {
        x: a.label,
        y: a.count
      }
    end
  end

  def sum_rollups(rollups)
    rollups.map { |r| r[:count] }.reduce(:+)
  end

  def interval_options
    [
      ["Hourly", "HOUR"],
      ["Daily", "DAY"],
      ["Weekly", "WEEK"],
      ["Monthly", "MONTH"]
    ]
  end

  def date_range_options
    [
      ["Last 7 Days", [7.days.ago.utc.to_date, Time.zone.now.utc.to_date].to_json],
      ["Week to Date", [Time.zone.now.utc.beginning_of_week.to_date, Time.zone.now.utc.to_date].to_json],
      ["Last 14 Days", [14.days.ago.utc.to_date, Time.zone.now.utc.to_date].to_json],
      ["Last 28 Days", [28.days.ago.utc.to_date, Time.zone.now.utc.to_date].to_json],
      ["Last Month", [1.month.ago.utc.to_date, Time.zone.now.utc.to_date].to_json],
      ["Month to Date", [Time.zone.now.utc.beginning_of_month.to_date, Time.zone.now.utc.to_date].to_json],
      ["Last 3 Months", [3.months.ago.utc.to_date, Time.zone.now.utc.to_date].to_json],
      ["Last 6 Months", [6.months.ago.utc.to_date, Time.zone.now.utc.to_date].to_json],
      ["Last Year", [1.year.ago.utc.to_date, Time.zone.now.utc.to_date].to_json],
      ["Year to Date", [Time.zone.now.utc.beginning_of_year.to_date, Time.zone.now.utc.to_date].to_json]
    ]
  end

  def dropday_range_options
    [
      ["7 Days", 7],
      ["14 Days", 14],
      ["28 Days", 28],
      ["30 Days", 30],
      ["60 Days", 60],
      ["90 Days", 90]
    ]
  end

  def uniques_options
    [
      ["Last 7 Rolling", {selection: "last_7_rolling", interval: "DAY"}],
      ["Last 28 Rolling", {selection: "last_28_rolling", interval: "DAY"}],
      ["Calendar Week", {selection: "calendar_week", interval: "WEEK"}],
      ["Calendar Month", {selection: "calendar_month", interval: "MONTH"}]
    ]
  end
end
