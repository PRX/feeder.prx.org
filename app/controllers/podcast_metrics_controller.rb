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

  def publish_hour(episode)
    if episode.first_rss_published_at.present?
      episode.first_rss_published_at.beginning_of_hour
    else
      episode.published_at.beginning_of_hour
    end
  end
end
