module PodcastMetricsHelper
  def parse_episode_downloads(episode_rollups, date_start, date_end, date_trunc)
    episode_rollups.map do |d|
      {
        name: d[:ep].title,
        data: fill_missing_dates(d[:rollups], date_start, date_end, date_trunc)
      }
    end
  end

  def fill_missing_dates(rollups, date_start, date_end, date_trunc)
    date_range = generate_date_range(date_start, date_end, date_trunc)
    date_range.map do |date|
      rollup = rollups.select { |r| match_date(r.hour, date, date_trunc) }

      {
        x: date,
        y: rollup_count(rollup.first)
      }
    end
  end

  def generate_date_range(date_start, date_end, date_trunc)
    if date_trunc == "DAY"
      (date_start.to_date..(date_end.to_date - 1.day)).to_a
    elsif date_trunc == "MONTH"
      (date_start.to_date..(date_end.to_date - 1.day)).to_a.map do |d|
        d.strftime("%b %Y")
      end.uniq
    elsif date_trunc == "HOUR"
      (date_start.to_date..(date_end.to_date - 1.day)).to_a.map do |d|
        generate_24_hours(d)
      end.flatten.map do |d|
        d.strftime("%d %b %Y %H:%M:%S")
      end
    end
  end

  def match_date(hour, date, date_trunc)
    if date_trunc == "DAY"
      hour.to_date == date
    elsif date_trunc == "MONTH"
      hour.strftime("%b %Y") == date
    elsif date_trunc == "HOUR"
      hour.strftime("%d %b %Y %H:%M:%S") == date
    end
  end

  def generate_24_hours(date)
    start_hour = date.midnight
    hours = (0..23).to_a
    hours.map do |h|
      start_hour + h.hours
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
