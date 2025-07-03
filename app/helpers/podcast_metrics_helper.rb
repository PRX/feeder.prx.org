module PodcastMetricsHelper
  def parse_episode_downloads(episode_rollups, date_start, date_end)
    episode_rollups.map do |d|
      {
        name: d[:ep].title,
        data: fill_missing_dates(d[:rollups], date_start, date_end)
      }
    end
  end

  def fill_missing_dates(rollups, date_start, date_end)
    date_range = (date_start.to_date..(date_end.to_date - 1.day)).to_a

    date_range.map do |date|
      rollup = rollups.select { |r| r.hour.to_date == date }

      {
        x: date,
        y: rollup_count(rollup.first)
      }
    end
  end

  def rollup_count(rollup)
    if rollup.present?
      rollup.count
    else
      0
    end
  end

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

  def rollups_date_range_options
    [
      ["Last 7 Days", 7.days.ago],
      ["Last 14 Days", 14.days.ago],
      ["Last 28 Days", 28.days.ago]
    ]
  end
end
