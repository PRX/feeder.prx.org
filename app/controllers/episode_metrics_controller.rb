class EpisodeMetricsController < ApplicationController
  include MetricsUtils
  include MetricsQueries

  before_action :set_episode
  # before_action :check_clickhouse, except: %i[show]

  def show
  end

  def downloads
    @date_range = generate_date_range(Date.utc_today - 28.days, Date.utc_today, "DAY")

    @downloads = daterange_downloads(@episode)
    @rollups = single_rollups(@downloads, "Downloads")

    render partial: "metrics/downloads_card", locals: {
      rollups: @rollups,
      date_range: @date_range
    }
  end

  def feeds
    feed_slugs = @episode.feeds.pluck(:slug).map { |slug| slug.nil? ? "" : slug }

    @downloads_by_feed = downloads_by_feed(@episode, feed_slugs)

    feeds_with_downloads = []

    @feeds = @downloads_by_feed.map do |rollup|
      feed = if rollup[:feed_slug].blank?
        @episode.podcast.default_feed
      else
        @episode.feeds.where(slug: rollup[:feed_slug]).first
      end

      feeds_with_downloads << feed

      {
        feed: feed,
        downloads: rollup
      }
    end

    @episode.feeds.each { |feed| @feeds << {feed: feed} if feeds_with_downloads.exclude?(feed) }

    render partial: "metrics/feeds_card", locals: {
      podcast: @episode.podcast,
      feeds: @feeds
    }
  end

  def geos
  end

  def agents
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
end
