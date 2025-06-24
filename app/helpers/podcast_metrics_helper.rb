module PodcastMetricsHelper
  def chart_options(series, opts)
    {
      chart: {
        type: opts[:chart][:type],
        height: "100%",
        width: "100%"
      },
      series: [
        {
          data: series
        }
      ],
      xaxis: {
        type: opts[:xaxis][:type]
      }
    }
  end

  def line_options
    {
      chart: {
        type: "line"
      },
      xaxis: {
        type: "datetime"
      }
    }
  end

  def parse_datetime(data)
    data.map do |d|
      [d["hour"].strftime("%F"), d["count"]]
    end
  end
end
