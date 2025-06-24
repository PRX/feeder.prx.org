class PodcastMetricsController < ApplicationController
  before_action :set_podcast

  def show
    authorize @podcast, :show?

    if clickhouse_connected?
      @recent_downloads =
        Rollups::HourlyDownload
          .where(podcast_id: @podcast.id, hour: 30.days.ago..)
          .select(:feed_slug, "DATE_TRUNC('DAY', hour) AS hour", "SUM(count) AS count")
          .group(:feed_slug, "DATE_TRUNC('DAY', hour) AS hour")
          .order(Arel.sql("DATE_TRUNC('DAY', hour) DESC"))
          .limit(10)
      @timezoned =
        Rollups::HourlyDownload
          .where(podcast_id: @podcast.id, hour: 7.days.ago..)
          .select(:feed_slug, "DATE_TRUNC('DAY', hour, 'America/Denver') AS hour", "SUM(count) AS count")
          .group(:feed_slug, "DATE_TRUNC('DAY', hour, 'America/Denver') AS hour")
          .order(Arel.sql("DATE_TRUNC('DAY', hour, 'America/Denver') DESC"))
          .limit(10)
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
    end
  end

  private

  def set_podcast
    @podcast = Podcast.find(params[:podcast_id])
  end
end
