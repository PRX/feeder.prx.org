class PodcastMetricsController < ApplicationController
  include MetricsUtils

  rescue_from ActiveRecord::ActiveRecordError, with: :render_metrics_error
  before_action :set_podcast
  before_action :check_clickhouse, except: %i[show]

  def show
  end

  def episode_sparkline
    @episode = Episode.find_by(guid: params[:episode_id])

    render partial: "metrics/episode_sparkline", locals: {
      episode: @episode,
      downloads: @episode.sparkline_downloads.to_a
    }
  end

  def episode_trend
    @episode = Episode.find_by(guid: params[:episode_id])

    render partial: "metrics/episode_trend", locals: {
      episode: @episode,
      episode_trend: @episode.episode_trend
    }
  end

  def score_card
    @score_type = params[:score_type]
    @score = scorecard_downloads(@score_type)

    render partial: "metrics/score_card", locals: {
      score: @score,
      score_type: @score_type
    }
  end

  def monthly_downloads
    render partial: "metrics/monthly_card", locals: {
      date_range: @podcast.generate_monthly_date_range,
      downloads: @podcast.monthly_downloads.to_a
    }
  end

  def episodes
    render partial: "metrics/episodes_card", locals: {
      episode_rollups: @podcast.downloads_by_episode,
      date_range: @podcast.generate_daily_date_range
    }
  end

  def feeds
    render partial: "metrics/feeds_card", locals: {
      podcast: @podcast,
      feeds: @podcast.feed_download_rollups
    }
  end

  def seasons
    render partial: "metrics/seasons_card", locals: {
      seasons: @podcast.season_download_rollups
    }
  end

  def countries
    render partial: "metrics/countries_card", locals: {
      countries: @podcast.country_download_rollups
    }
  end

  def agents
    render partial: "metrics/agent_apps_card", locals: {
      agents: @podcast.agent_download_rollups
    }
  end

  private

  def set_podcast
    @podcast = Podcast.find(params[:podcast_id])
    authorize @podcast, :show?
  rescue ActiveRecord::RecordNotFound => e
    render_not_found(e)
  end

  def scorecard_downloads(score_type)
    if score_type == "daterange"
      @podcast.daily_downloads.values.sum
    elsif score_type == "alltime"
      @podcast.alltime_downloads
    elsif score_type == "episodes"
      @podcast.episodes.published.length
    end
  end
end
