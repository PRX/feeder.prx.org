module PodcastMetricsHelper
  def line_chart_colors
    ["#007EB2", "#FF9600", "#75BBE1", "#FFC107", "#6F42C1", "#DC3545", "#198754", "#D63384", "#20C997", "#555555"]
  end

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

  def generate_date_range(date_start, date_end, interval)
    if interval == "DAY"
      (date_start.to_date..date_end.to_date).to_a
    elsif interval == "WEEK"
      start_week = date_start.to_date.beginning_of_week
      end_week = date_end.to_date.beginning_of_week
      range = []
      i = 0
      while start_week + i.weeks <= end_week
        range << start_week + i.weeks
        i += 1
      end

      range
    elsif interval == "MONTH"
      start_month = date_start.to_date.beginning_of_month
      end_month = date_end.to_date.beginning_of_month
      range = []
      i = 0
      while start_month + i.months <= end_month
        range << start_month + i.months
        i += 1
      end

      range
    elsif interval == "HOUR"
      start_hour = date_start.to_datetime.beginning_of_hour
      end_hour = date_end.to_datetime.beginning_of_hour
      range = []
      i = 0
      while start_hour + i.hours <= end_hour
        range << start_hour + i.hours
        i += 1
      end

      range
    end
  end
end
