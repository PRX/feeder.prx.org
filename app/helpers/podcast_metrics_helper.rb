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

  def interval_options(date_start, date_end)
    day_count = (date_start.to_date..date_end.to_date).to_a.length
    if day_count > 60
      [
        ["Daily", "DAY"],
        ["Weekly", "WEEK"],
        ["Monthly", "MONTH"]
      ]
    elsif day_count < 30
      [
        ["Hourly", "HOUR"],
        ["Daily", "DAY"],
        ["Weekly", "WEEK"]
      ]
    else
      [
        ["Hourly", "HOUR"],
        ["Daily", "DAY"],
        ["Weekly", "WEEK"],
        ["Monthly", "MONTH"]
      ]
    end
  end

  def rollups_date_range_options
    [
      ["Last 7 Days", 7.days.ago.utc.to_date],
      ["Week to Date", Time.zone.now.utc.beginning_of_week.to_date],
      ["Last 14 Days", 14.days.ago.utc.to_date],
      ["Last 28 Days", 28.days.ago.utc.to_date],
      ["Last Month", 1.month.ago.utc.to_date],
      ["Month to Date", Time.zone.now.utc.beginning_of_month.to_date],
      ["Last 3 Months", 3.months.ago.utc.to_date],
      ["Last 6 Months", 6.months.ago.utc.to_date],
      ["Last Year", 1.year.ago.utc.to_date],
      ["Year to Date", Time.zone.now.utc.beginning_of_year.to_date]
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
end
