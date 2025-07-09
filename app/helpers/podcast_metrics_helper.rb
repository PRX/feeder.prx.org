module PodcastMetricsHelper
  def line_chart_colors
    ["#007EB2", "#FF9600", "#75BBE1", "#FFC107", "#6F42C1", "#DC3545", "#198754", "#D63384", "#20C997", "#555555"]
  end

  def parse_agent_data(agents)
    [
      {
        data: agents.map do |a|
          {
            x: a.label,
            y: a.count
          }
        end
      }
    ]
  end

  def sum_rollups(rollups)
    rollups.map { |r| r[:count] }.reduce(:+)
  end

  def date_trunc_options
    [
      ["Hourly", "HOUR"],
      ["Daily", "DAY"],
      ["Monthly", "MONTH"]
    ]
  end

  def rollups_date_range_options
    [
      ["Last 7 Days", 7.days.ago],
      ["Last 14 Days", 14.days.ago],
      ["Last 28 Days", 28.days.ago]
    ]
  end
end
