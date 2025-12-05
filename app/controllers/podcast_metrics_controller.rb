class PodcastMetricsController < ApplicationController
  include MetricsUtils

  before_action :set_podcast
  before_action :check_clickhouse, except: %i[show]

  def show
  end

  def episode_sparkline
    @episode = Episode.find_by(guid: metrics_params[:episode_id])
    @prev_episode = Episode.find_by(guid: metrics_params[:prev_episode_id])

    @episode_trend = calculate_episode_trend(@episode, @prev_episode)
    @sparkline_downloads =
      Rollups::HourlyDownload
        .where(episode_id: @episode[:guid], hour: (@episode.first_rss_published_at..Date.utc_today))
        .final
        .select(:episode_id, "DATE_TRUNC('DAY', hour) AS hour", "SUM(count) AS count")
        .group(:episode_id, "DATE_TRUNC('DAY', hour) AS hour")
        .order(Arel.sql("DATE_TRUNC('DAY', hour) ASC"))
        .load_async

    render partial: "metrics/episode_sparkline", locals: {
      episode: @episode,
      downloads: @sparkline_downloads,
      episode_trend: @episode_trend
    }
  end

  def downloads
    @downloads_within_date_range =
      Rollups::HourlyDownload
        .where(podcast_id: @podcast.id, hour: (@date_start..@date_end))
        .select("DATE_TRUNC('#{@interval}', hour) AS hour", "SUM(count) AS count")
        .group("DATE_TRUNC('#{@interval}', hour) AS hour")
        .order(Arel.sql("DATE_TRUNC('#{@interval}', hour) ASC"))
        .load_async

    @downloads = single_rollups(@downloads_within_date_range)

    render partial: "metrics/downloads_card", locals: {
      url: request.fullpath,
      form_id: "podcast_downloads_metrics",
      date_start: @date_start,
      date_end: @date_end,
      interval: @interval,
      date_range: @date_range,
      downloads: @downloads
    }
  end

  def episodes
    @episodes =
      @podcast.episodes
        .published
        .order(first_rss_published_at: :desc)
        .paginate(params[:episodes], params[:per])

    @episodes_recent =
      Rollups::HourlyDownload
        .where(podcast_id: @podcast.id, episode_id: @episodes.pluck(:guid), hour: (@date_start..@date_end))
        .select(:episode_id, "DATE_TRUNC('#{@interval}', hour) AS hour", "SUM(count) AS count")
        .group(:episode_id, "DATE_TRUNC('#{@interval}', hour) AS hour")
        .order(Arel.sql("DATE_TRUNC('#{@interval}', hour) ASC"))
        .load_async
    @episodes_alltime =
      Rollups::HourlyDownload
        .where(podcast_id: @podcast.id, episode_id: @episodes.pluck(:guid))
        .select(:episode_id, "SUM(count) AS count")
        .group(:episode_id)
        .load_async

    @episode_rollups = multiple_episode_rollups(@episodes, @episodes_recent, @episodes_alltime)

    render partial: "metrics/episodes_card", locals: {
      url: request.fullpath,
      form_id: "podcast_episodes_metrics",
      date_start: @date_start,
      date_end: @date_end,
      interval: @interval,
      date_range: @date_range,
      episodes: @episodes,
      episode_rollups: @episode_rollups
    }
  end

  def uniques
    @uniques_rollups =
      Rollups::DailyUnique
        .where(podcast_id: @podcast.id, day: (@date_start..@date_end))
        .select("DATE_TRUNC('#{@interval}', day) AS day, MAX(#{@uniques_selection}) AS #{@uniques_selection}")
        .group("DATE_TRUNC('#{@interval}', day) AS day")
        .order(Arel.sql("DATE_TRUNC('#{@interval}', day) ASC"))
        .load_async

    @uniques = single_rollups(@uniques_rollups)

    render partial: "metrics/uniques_card", locals: {
      url: request.fullpath,
      form_id: "podcast_uniques_metrics",
      date_start: @date_start,
      date_end: @date_end,
      interval: @interval,
      uniques_selection: @uniques_selection,
      uniques: @uniques,
      date_range: @date_range
    }
  end

  def dropdays
    @episodes =
      @podcast.episodes
        .published
        .order(first_rss_published_at: :desc)
        .paginate(params[:episode_dropdays], params[:per])

    @interval = dropdays_params[:interval]
    @fudged_range = if @interval == "DAY"
      # first day is not a "complete" day
      # fudged range matches chart selection
      @dropday_range.to_i - 1
    elsif @interval == "HOUR"
      @dropday_range.to_i
    end
    @dropdays = @episodes.map do |ep|
      if ep[:first_rss_published_at]
        Rollups::HourlyDownload
          .where(episode_id: ep[:guid], hour: (ep.first_rss_published_at..(ep.first_rss_published_at + @fudged_range.send(:"#{@interval.downcase}s"))))
          .select(:episode_id, "DATE_TRUNC('#{@interval}', hour) AS hour", "SUM(count) AS count")
          .group(:episode_id, "DATE_TRUNC('#{@interval}', hour) AS hour")
          .order(Arel.sql("DATE_TRUNC('#{@interval}', hour) ASC"))
          .load_async
      else
        []
      end
    end.flatten
    @alltime_downloads_by_episode =
      Rollups::HourlyDownload
        .where(podcast_id: @podcast.id, episode_id: @episodes.pluck(:guid))
        .select(:episode_id, "SUM(count) AS count")
        .group(:episode_id)
        .load_async

    @episode_dropdays = multiple_episode_rollups(@episodes, @dropdays, @alltime_downloads_by_episode)

    render partial: "metrics/dropdays_card", locals: {
      url: request.fullpath,
      form_id: "podcast_dropdays_metrics",
      episode_dropdays: @episode_dropdays,
      dropday_range: @dropday_range,
      interval: @interval
    }
  end

  def geos
    # @top_subdivs =
    #   Rollups::DailyGeo
    #     .where(podcast_id: @podcast.id)
    #     .select(:country_code, :subdiv_code, "DATE_TRUNC('WEEK', day) AS day", "SUM(count) AS count")
    #     .group(:country_code, :subdiv_code, "DATE_TRUNC('WEEK', day) AS day")
    #     .order(Arel.sql("SUM(count) AS count DESC"))
    #     .limit(10)
    # @top_countries =
    #   Rollups::DailyGeo
    #     .where(podcast_id: @podcast.id)
    #     .select(:country_code, "SUM(count) AS count")
    #     .group(:country_code)
    #     .order(Arel.sql("SUM(count) AS count DESC"))
    #     .limit(10)
  end

  def agents
    # @agent_apps_query =
    #   Rollups::DailyAgent
    #     .where(podcast_id: @podcast.id)
    #     .select("agent_name_id AS code", "SUM(count) AS count")
    #     .group("agent_name_id AS code")
    #     .order(Arel.sql("SUM(count) AS count DESC"))
    #     .load_async
    # @agent_types_query =
    #   Rollups::DailyAgent
    #     .where(podcast_id: @podcast.id)
    #     .select("agent_type_id AS code", "SUM(count) AS count")
    #     .group("agent_type_id AS code")
    #     .order(Arel.sql("SUM(count) AS count DESC"))
    #     .load_async
    # @agent_os_query =
    #   Rollups::DailyAgent
    #     .where(podcast_id: @podcast.id)
    #     .select("agent_os_id AS code", "SUM(count) AS count")
    #     .group("agent_os_id AS code")
    #     .order(Arel.sql("SUM(count) AS count DESC"))
    #     .load_async

    # @agent_apps = Kaminari.paginate_array(@agent_apps_query).page(params[:agent_apps]).per(10)
    # @agent_types = Kaminari.paginate_array(@agent_types_query).page(params[:agent_types]).per(10)
    # @agent_os = Kaminari.paginate_array(@agent_os_query).page(params[:agent_os]).per(10)

    # render partial: "agents", locals: {
    #   agent_apps: @agent_apps,
    #   agent_types: @agent_types,
    #   agent_os: @agent_os
    # }
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

  def calculate_episode_trend(episode, prev_episode)
    return nil unless episode.in_default_feed? && episode.first_rss_published_at.present? && prev_episode.present?
    return nil if (episode.first_rss_published_at + 1.day) > Time.now

    ep_dropday_sum = episode_dropday_query(episode)
    previous_ep_dropday_sum = episode_dropday_query(prev_episode)

    return nil if ep_dropday_sum <= 0 || previous_ep_dropday_sum <= 0

    ((ep_dropday_sum.to_f / previous_ep_dropday_sum.to_f) - 1).round(2)
  end

  def episode_dropday_query(ep)
    lowerbound = ep.first_rss_published_at.beginning_of_hour
    upperbound = lowerbound + 24.hours

    Rollups::HourlyDownload
      .where(episode_id: ep[:guid], hour: (lowerbound..upperbound))
      .final
      .sum(:count)
  end
end
