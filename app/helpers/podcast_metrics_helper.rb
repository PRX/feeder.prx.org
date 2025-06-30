module PodcastMetricsHelper
  def chart_options(type:, height: "", width: "")
    {
      type: type,
      height: height,
      width: width,
      zoom: {enabled: false},
      animations: {
        speed: 1000,
        animateGradually: {
          delay: 50
        }
      }
    }
  end

  def parse_episode_downloads(data, date_start, date_end)
    data.map do |d|
      {
        name: d[:ep].title,
        data: parse_datetime_data(d[:rollups], date_start, date_end)
      }
    end.first(10)
  end

  def parse_datetime_data(data, date_start, date_end)
    date_range = (date_start.to_date..date_end.to_date).to_a

    date_range.map do |date|
      point = data.select { |d| d["hour"].to_date == date }
      if point.present?
        {
          x: date,
          y: point.first["count"]
        }
      else
        {
          x: date,
          y: 0
        }
      end
    end
  end

  def sum_rollups(rollups)
    rollups.map { |r| r[:count] }.reduce(:+)
  end
end
