class EpisodeMetricsController < ApplicationController
  include MetricsUtils
  include MetricsQueries

  before_action :set_episode
  # before_action :check_clickhouse, except: %i[show]

  def show
  end

  def score_card
    @score_type = params[:score_type]
    @score = scorecard_downloads(@score_type)

    render partial: "metrics/score_card", locals: {
      score: @score,
      score_type: @score_type
    }
  end

  def downloads
    @date_range = generate_date_range(Date.utc_today - 28.days, Date.utc_today, "DAY")

    @downloads = @episode.daterange_downloads
    @rollups = single_rollups(@downloads, "Downloads")

    render partial: "metrics/downloads_card", locals: {
      rollups: @rollups,
      date_range: @date_range
    }
  end

  def feeds
    render partial: "metrics/feeds_card", locals: {
      podcast: @episode.podcast,
      feeds: @episode.feed_download_rollups
    }
  end

  def countries
    render partial: "metrics/countries_card", locals: {
      countries: @episode.country_download_rollups
    }
  end

  def agents
    render partial: "metrics/agent_apps_card", locals: {
      agents: @episode.agent_download_rollups
    }
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

  def scorecard_downloads(score_type)
    if score_type == "daterange"
      @episode.daterange_downloads.sum(&:count)
    elsif score_type == "alltime"
      @episode.alltime_downloads.sum(&:count)
    end
  end
end
