class EpisodeMetricsController < ApplicationController
  include MetricsUtils

  before_action :set_episode
  before_action :set_date_range

  def show
  end

  def downloads
    if clickhouse_connected?
      @downloads_within_date_range =
        Rollups::HourlyDownload
          .where(episode_id: @episode.guid, hour: (@date_start..@date_end))
          .select("DATE_TRUNC('#{@interval}', hour) AS hour", "SUM(count) AS count")
          .group("DATE_TRUNC('#{@interval}', hour) AS hour")
          .order(Arel.sql("DATE_TRUNC('#{@interval}', hour) ASC"))
          .load_async
    end

    @downloads = single_rollups(@downloads_within_date_range, @episode.title)

    render partial: "metrics/downloads_card", locals: {
      url: downloads_episode_metrics_path(episode: @episode, date_start: @date_start, date_end: @date_end, interval: @interval),
      form_id: "episode_downloads_metrics",
      date_start: @date_start,
      date_end: @date_end,
      interval: @interval,
      date_range: @date_range,
      downloads: @downloads
    }
  end

  def geos
  end

  def agents
  end

  private

  def set_episode
    @episode = Episode.find_by(guid: params[:episode_id])
    @podcast = @episode.podcast
    authorize @episode, :show?
  end

  def set_date_range
    @date_start = metrics_params[:date_start]
    @date_end = metrics_params[:date_end]
    @interval = metrics_params[:interval]
    @date_range = generate_date_range(@date_start, @date_end, @interval)
  end

  def metrics_params
    params
      .permit(:episode_id, :date_start, :date_end, :interval)
      .with_defaults(
        date_start: 28.days.ago.utc_date,
        date_end: Date.utc_today,
        interval: "DAY"
      )
  end
end
