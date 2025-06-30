class PodcastMetricsController < ApplicationController
  before_action :set_podcast

  def show
    authorize @podcast, :show?

    @episodes =
      @podcast.episodes
        .published
        .order(published_at: :desc)
        .paginate(params[:page], params[:per])
    @date_start = 30.days.ago
    @date_end = Time.zone.now

    if clickhouse_connected?
      @recent_downloads_by_episode =
        Rollups::HourlyDownload
          .where(podcast_id: @podcast.id, episode_id: @episodes.pluck(:guid), hour: (@date_start..@date_end))
          .select(:episode_id, "DATE_TRUNC('DAY', hour) AS hour", "SUM(count) AS count")
          .group(:episode_id, "DATE_TRUNC('DAY', hour) AS hour")
          .order(Arel.sql("DATE_TRUNC('DAY', hour) DESC"))
      @alltime_downloads_by_episode =
        Rollups::HourlyDownload
          .where(podcast_id: @podcast.id, episode_id: @episodes.pluck(:guid))
          .select(:episode_id, "SUM(count) AS count")
          .group(:episode_id)

      @recent_downloads_total =
        Rollups::HourlyDownload
          .where(podcast_id: @podcast.id, hour: (@date_start..@date_end))
          .select("SUM(count) AS count")
          .group(:podcast_id)
          .order(:podcast_id)
      @alltime_downloads_total =
        Rollups::HourlyDownload
          .where(podcast_id: @podcast.id)
          .select("SUM(count) AS count")
          .group(:podcast_id)
          .order(:podcast_id)

      @top_subdivs =
        Rollups::DailyGeo
          .where(podcast_id: @podcast.id)
          .select(:country_code, :subdiv_code, "DATE_TRUNC('WEEK', day) AS day", "SUM(count) AS count")
          .group(:country_code, :subdiv_code, "DATE_TRUNC('WEEK', day) AS day")
          .order(Arel.sql("SUM(count) AS count DESC"))
          .limit(10)
      @top_countries =
        Rollups::DailyGeo
          .where(podcast_id: @podcast.id)
          .select(:country_code, "SUM(count) AS count")
          .group(:country_code)
          .order(Arel.sql("SUM(count) AS count DESC"))
          .limit(10)
      @agents =
        Rollups::DailyAgent
          .where(podcast_id: @podcast.id)
          .select("*")
          .group("*")
          .limit(10)
      @geos =
        Rollups::DailyGeo
          .where(podcast_id: @podcast.id)
          .select("*")
          .group("*")
          .limit(10)
      @uniques =
        Rollups::DailyUnique
          .where(podcast_id: @podcast.id)
          .select("*")
          .group("*")
          .limit(10)

      @episode_rollups = episode_rollups(@episodes, @recent_downloads_by_episode, @alltime_downloads_by_episode)
    end
  end

  private

  def set_podcast
    @podcast = Podcast.find(params[:podcast_id])
  end

  def episode_rollups(episodes, rollups, totals)
    episodes.map do |ep|
      {
        ep: ep,
        rollups: rollups.select do |r|
          r["episode_id"] == ep.guid
        end,
        totals: totals.select do |r|
          r["episode_id"] == ep.guid
        end
      }
    end
  end
end
