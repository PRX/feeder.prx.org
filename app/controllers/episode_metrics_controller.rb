class EpisodeMetricsController < ApplicationController
  include MetricsUtils

  rescue_from ActiveRecord::ActiveRecordError, with: :render_metrics_error
  before_action :set_episode
  before_action :check_clickhouse, except: %i[show]

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
    render partial: "metrics/downloads_card", locals: {
      rollups: @episode.daily_downloads.to_a
    }
  end

  def feeds
    render partial: "metrics/feeds_card", locals: {
      podcast: @episode.podcast,
      feeds: @episode.feed_downloads.to_a
    }
  end

  def countries
    render partial: "metrics/countries_card", locals: {
      countries: @episode.country_download_rollups.to_a
    }
  end

  def agents
    render partial: "metrics/agent_apps_card", locals: {
      agents: @episode.agent_download_rollups.to_a
    }
  end

  private

  def set_episode
    @episode = Episode.find_by(guid: params[:episode_id])
    @podcast = @episode.podcast
    authorize @episode, :show?
  end

  def scorecard_downloads(score_type)
    if score_type == "daterange"
      @episode.daily_downloads.values.sum
    elsif score_type == "alltime"
      @episode.alltime_downloads
    end
  end
end
