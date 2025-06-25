module PodcastMetricsHelper
  def chart_options(type:, height: "", width: "")
    {
      type: type,
      height: height,
      width: width,
      zoom: { enabled: false }
    }
  end

  def parse_series(data)
    {
      name: data[0][:feed_slug],
      data: parse_datetime(data)
    }
  end

  def parse_datetime(data)
    data.map do |d|
      [d["hour"].strftime("%F"), d["count"]]
    end
  end
end
