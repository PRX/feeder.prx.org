class PodcastMetricsController < ApplicationController
  include MetricsUtils
  include MetricsQueries

  before_action :set_podcast
  # before_action :check_clickhouse, except: %i[show]

  def show
  end

  def episode_sparkline
    @episode = Episode.find_by(guid: params[:episode_id])

    render partial: "metrics/episode_sparkline", locals: {
      episode: @episode,
      downloads: @episode.sparkline_downloads
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
    @date_start = (Date.utc_today - 11.months).beginning_of_month
    @date_end = Date.utc_today
    @date_range = generate_date_range(@date_start, @date_end.beginning_of_month, "MONTH")
    @downloads_within_date_range = daterange_downloads(@podcast, @date_start, @date_end, "MONTH")

    @downloads = single_rollups(@downloads_within_date_range, "Downloads")

    render partial: "metrics/monthly_card", locals: {
      date_range: @date_range,
      downloads: @downloads
    }
  end

  def episodes
    @episodes = @podcast.episodes.published.dropdate_desc.limit(10)
    @date_range = generate_date_range(Date.utc_today - 28.days, Date.utc_today, "DAY")

    @episodes_downloads = daterange_downloads(@episodes)

    @episode_rollups = multiple_episode_rollups(@episodes, @episodes_downloads)

    render partial: "metrics/episodes_card", locals: {
      episode_rollups: @episode_rollups,
      date_range: @date_range
    }
  end

  def feeds
    render partial: "metrics/feeds_card", locals: {
      podcast: @podcast,
      feeds: @podcast.feed_download_rollups
    }
  end

  def seasons
    published_seasons = @podcast.episodes.published.pluck(:season_number).uniq.compact

    @season_rollups = published_seasons.map do |season|
      {
        season_number: season,
        downloads: @podcast.downloads_by_season(season)
      }
    end.sort { |a, b| b[:downloads] <=> a[:downloads] }

    render partial: "metrics/seasons_card", locals: {
      seasons: @season_rollups
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

  def metrics_params
    params
      .permit(:podcast_id, :episode_id, :prev_episode_id)
  end

  def publish_hour(episode)
    if episode.first_rss_published_at.present?
      episode.first_rss_published_at.beginning_of_hour
    else
      episode.published_at.beginning_of_hour
    end
  end

  def scorecard_downloads(score_type)
    if score_type == "daterange"
      daterange_downloads(@podcast).sum(&:count)
    elsif score_type == "alltime"
      alltime_downloads(@podcast).sum(&:count)
    elsif score_type == "episodes"
      @podcast.episodes.published.length
    end
  end
end
