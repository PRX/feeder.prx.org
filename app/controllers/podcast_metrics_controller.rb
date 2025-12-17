class PodcastMetricsController < ApplicationController
  include MetricsUtils
  include MetricsQueries

  before_action :set_podcast
  # before_action :check_clickhouse, except: %i[show]

  def show
  end

  def episode_sparkline
    @episode = Episode.find_by(guid: metrics_params[:episode_id])
    @prev_episode = Episode.find_by(guid: metrics_params[:prev_episode_id])

    @episode_trend = calculate_episode_trend(@episode, @prev_episode)

    @sparkline_downloads =
      Rollups::HourlyDownload
        .where(episode_id: @episode[:guid], hour: (publish_hour(@episode)..publish_hour(@episode) + 6.months))
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
    feed_slugs = @podcast.feeds.pluck(:slug).map { |slug| slug.nil? ? "" : slug }

    @downloads_by_feed = downloads_by_feed(@podcast, feed_slugs)

    feeds_with_downloads = []

    @feeds = @downloads_by_feed.map do |rollup|
      feed = if rollup[:feed_slug].blank?
        @podcast.default_feed
      else
        @podcast.feeds.where(slug: rollup[:feed_slug]).first
      end

      feeds_with_downloads << feed

      {
        feed: feed,
        downloads: rollup
      }
    end

    @podcast.feeds.each { |feed| @feeds << {feed: feed} if feeds_with_downloads.exclude?(feed) }

    render partial: "metrics/feeds_card", locals: {
      podcast: @podcast,
      feeds: @feeds
    }
  end

  def seasons
    published_seasons = @podcast.episodes.published.pluck(:season_number).uniq

    @season_rollups = published_seasons.map do |season|
      episodes = @podcast.episodes.published.where(season_number: season)
      rollup = alltime_downloads(episodes, "podcast_id")

      {
        season_number: season,
        downloads: rollup.first
      }
    end

    render partial: "metrics/seasons_card", locals: {
      seasons: @season_rollups
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

  def countries
    top_countries = top_countries_rollups(@podcast)
    top_country_codes = top_countries.pluck(:country_code)

    other_countries = other_countries_rollups(@podcast, top_country_codes)

    @country_rollups = []
    @country_rollups << top_countries
    @country_rollups << other_countries

    render partial: "metrics/countries_card", locals: {
      countries: @country_rollups.flatten
    }
  end

  def agents
    agent_apps = top_agents_rollups(@podcast)
    top_apps_ids = agent_apps.pluck(:code)

    other_apps = other_agents_rollups(@podcast, top_apps_ids)

    @agent_rollups = []
    @agent_rollups << agent_apps
    @agent_rollups << other_apps

    render partial: "metrics/agent_apps_card", locals: {
      agents: @agent_rollups.flatten
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

  def calculate_episode_trend(episode, prev_episode)
    return nil unless episode.first_rss_published_at.present? && prev_episode.present?
    return nil if (episode.first_rss_published_at + 1.day) > Time.now

    ep_dropday_sum = episode_dropday_query(episode)
    previous_ep_dropday_sum = episode_dropday_query(prev_episode)

    return nil if ep_dropday_sum <= 0 || previous_ep_dropday_sum <= 0

    ((ep_dropday_sum.to_f / previous_ep_dropday_sum.to_f) - 1).round(3)
  end

  def episode_dropday_query(ep)
    lowerbound = publish_hour(ep)
    upperbound = lowerbound + 24.hours

    Rollups::HourlyDownload
      .where(episode_id: ep[:guid], hour: (lowerbound...upperbound))
      .final
      .load_async
      .sum(:count)
  end

  def publish_hour(episode)
    if episode.first_rss_published_at.present?
      episode.first_rss_published_at.beginning_of_hour
    else
      episode.published_at.beginning_of_hour
    end
  end
end
