class PodcastMetricsController < ApplicationController
  before_action :set_podcast
  before_action :set_date_range, only: %i[show downloads episodes uniques]

  def show
  end

  def downloads
    @episodes =
      @podcast.episodes
        .published
        .order(first_rss_published_at: :desc)
        .paginate(params[:episode_rollups], params[:per])

    if clickhouse_connected?
      @downloads_within_date_range =
        Rollups::HourlyDownload
          .where(podcast_id: @podcast.id, hour: (@date_start..@date_end))
          .select("DATE_TRUNC('#{@interval}', hour) AS hour", "SUM(count) AS count")
          .group("DATE_TRUNC('#{@interval}', hour) AS hour")
          .order(Arel.sql("DATE_TRUNC('#{@interval}', hour) ASC"))
          .load_async
    end

    @downloads = {
      rollups: @downloads_within_date_range,
      color: colors[0]
    }

    render partial: "downloads_card", locals: {
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

    if clickhouse_connected?
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
    end

    @episode_rollups = episode_rollups(@episodes, @episodes_recent, @episodes_alltime)

    render partial: "episodes_card", locals: {
      interval: @interval,
      date_range: @date_range,
      episodes: @episodes,
      episode_rollups: @episode_rollups
    }
  end

  def uniques
    @selection = uniques_params[:uniques_selection]

    if clickhouse_connected?
      @uniques_rollups =
        Rollups::DailyUnique
          .where(podcast_id: @podcast.id, day: (@date_start..@date_end))
          .select("DATE_TRUNC('#{@interval}', day) AS day, MAX(#{@selection}) AS #{@selection}")
          .group("DATE_TRUNC('#{@interval}', day) AS day")
          .order(Arel.sql("DATE_TRUNC('#{@interval}', day) ASC"))
          .load_async
    end

    @uniques = {
      rollups: @uniques_rollups,
      color: colors[0]
    }

    render partial: "uniques_card", locals: {
      interval: @interval,
      selection: @selection,
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

    @dropdays = @episodes.map do |ep|
      if ep[:first_rss_published_at]
        Rollups::HourlyDownload
          .where(episode_id: ep[:guid], hour: (ep.first_rss_published_at..(ep.first_rss_published_at + metrics_params[:dropday_range].to_i.days)))
          .select(:episode_id, "DATE_TRUNC('DAY', hour) AS hour", "SUM(count) AS count")
          .group(:episode_id, "DATE_TRUNC('DAY', hour) AS hour")
          .order(Arel.sql("DATE_TRUNC('DAY', hour) ASC"))
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

    @episode_dropdays = episode_rollups(@episodes, @dropdays, @alltime_downloads_by_episode)

    render partial: "dropdays_card", locals: {
      episode_dropdays: @episode_dropdays,
      episodes: @episodes,
      dropday_range: metrics_params[:dropday_range]
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
  end

  def set_date_range
    @date_start = metrics_params[:date_start]
    @date_end = metrics_params[:date_end]
    @interval = metrics_params[:interval]
    @date_range = generate_date_range(@date_start, @date_end, @interval)
  end

  def metrics_params
    params
      .permit(:podcast_id, :date_start, :date_end, :interval, :dropday_range)
      .with_defaults(
        date_start: 30.days.ago.utc,
        date_end: Time.zone.now.utc,
        interval: "DAY",
        dropday_range: 7
      )
  end

  def uniques_params
    metrics_params
      .permit(:uniques_selection)
      .with_defaults(
        uniques_selection: "last_7_rolling"
      )
  end

  def episode_rollups(episodes, rollups, totals)
    episodes.to_enum(:each_with_index).map do |episode, i|
      {
        episode: episode,
        rollups: rollups.select do |r|
          r["episode_id"] == episode.guid
        end,
        totals: totals.select do |r|
          r["episode_id"] == episode.guid
        end,
        color: colors[i]
      }
    end
  end

  def episode_dropdays(episodes, dropdays)
    episodes.to_enum(:each_with_index).map do |episode, i|
      {
        episode: episode,
        dropdays: dropdays.select do |d|
          d["episode_id"] == episode.guid
        end,
        color: colors[i]
      }
    end
  end

  def generate_date_range(date_start, date_end, interval)
    start_range = date_start.to_datetime.utc.send(:"beginning_of_#{interval.downcase}")
    end_range = date_end.to_datetime.utc.send(:"beginning_of_#{interval.downcase}")
    range = []
    i = 0

    while start_range + i.send(:"#{interval.downcase.pluralize}") <= end_range
      range << start_range + i.send(:"#{interval.downcase.pluralize}")
      i += 1
    end

    range
  end

  def colors
    [
      "#007EB2",
      "#FF9600",
      "#75BBE1",
      "#FFC107",
      "#6F42C1",
      "#DC3545",
      "#198754",
      "#D63384",
      "#20C997",
      "#555555"
    ]
  end
end
