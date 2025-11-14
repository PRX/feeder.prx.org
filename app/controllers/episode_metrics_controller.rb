class EpisodeMetricsController < ApplicationController
  include MetricsUtils
  include MetricsQueries

  before_action :set_episode
  before_action :check_clickhouse, except: %i[show]
  before_action :set_date_range
  before_action :set_tabs

  def show
  end

  def downloads
    @downloads_within_date_range = downloads_date_range_query(@episode, @date_start, @date_end, @interval)
    @downloads = single_rollups(@downloads_within_date_range, @episode.title)

    render partial: "metrics/downloads_card", locals: {
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
    @date_preset = metrics_params[:date_preset]
    @date_start = metrics_params[:date_start]
    @date_end = metrics_params[:date_end]
    @interval = metrics_params[:interval]
    @date_range = generate_date_range(@date_start, @date_end, @interval)
  end

  def set_tabs
    @main_card = metrics_params[:main_card]
    @agents_card = metrics_params[:agents_card]
  end

  def metrics_params
    params
      .permit(:episode_id, :date_preset, :date_start, :date_end, :interval, :main_card, :agents_card)
      .with_defaults(
        date_preset: "last_30_days",
        date_start: 30.days.ago.utc_date,
        date_end: Date.utc_today,
        interval: "DAY",
        main_card: "downloads",
        agents_card: "agent_apps"
      )
  end
end
