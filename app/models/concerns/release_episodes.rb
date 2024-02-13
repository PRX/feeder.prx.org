require "active_support/concern"

module ReleaseEpisodes
  extend ActiveSupport::Concern

  EPISODE_PUBLISH_TIMES = <<-SQL.squish
    SELECT
      e.id AS episode_id,
      e.podcast_id AS podcast_id,
      f.id AS feed_id,
      e.published_at + MAKE_INTERVAL(secs => COALESCE(f.episode_offset_seconds, 0)) AS publish_time
    FROM episodes e
    LEFT JOIN feeds f USING (podcast_id)
    WHERE e.published_at IS NOT NULL
    AND e.deleted_at IS NULL
    AND f.deleted_at IS NULL
  SQL

  LATEST_QUEUE_TIMES = <<-SQL.squish
    SELECT podcast_id, MAX(created_at) AS latest_queue_time
    FROM publishing_queue_items
    GROUP BY podcast_id
  SQL

  EPISODES_TO_RELEASE = <<-SQL.squish
    WITH
      episode_publish_times AS (#{EPISODE_PUBLISH_TIMES}),
      latest_queue_times AS (#{LATEST_QUEUE_TIMES})
    SELECT episode_id, podcast_id, feed_id, publish_time
    FROM episode_publish_times
    LEFT JOIN latest_queue_times USING (podcast_id)
    WHERE publish_time <= NOW()
    AND (latest_queue_time IS NULL OR publish_time > latest_queue_time)
  SQL

  included do
    scope :to_release, -> do
      case name
      when "Podcast"
        where("id IN (SELECT DISTINCT podcast_id FROM (#{EPISODES_TO_RELEASE}) tbl)")
      when "Episode"
        where("id IN (SELECT DISTINCT episode_id FROM (#{EPISODES_TO_RELEASE}) tbl)")
      else
        none
      end
    end
  end

  class_methods do
    def release!
      Rails.logger.tagged("Podcast.release!") do
        PublishingPipelineState.expire_pipelines!
        PublishingPipelineState.retry_failed_pipelines!

        Podcast.to_release.order(created_at: :asc).each do |p|
          p.publish_updated
          p.publish!
        end
      end
    end
  end

  def self.to_release
    ActiveRecord::Base.connection.execute(EPISODES_TO_RELEASE)
  end

  # human readable output of what we need to release
  def self.to_release_debug
    res = to_release

    pods = Podcast.where(id: res.pluck("podcast_id")).order(created_at: :asc).load
    attempts = PublishingQueueItem.where(podcast_id: res.pluck("podcast_id")).group(:podcast_id).maximum(:created_at)
    feeds = Feed.where(id: res.pluck("feed_id")).order(created_at: :asc).load
    eps = Episode.where(id: res.pluck("episode_id")).order(created_at: :asc).load

    pods.map do |p|
      puts "\n#{p.id}: #{p.title} - last attempt #{attempts[p.id].to_s.blue}"

      feeds.select { |f| f.podcast_id == p.id }.map do |f|
        offset = (f.episode_offset_seconds.to_i == 0) ? "offset 0" : "offset #{f.episode_offset_seconds}".green
        puts "  #{f.id}: #{f.title || "Default"} - #{offset}"

        res.select { |r| r["feed_id"] == f.id }.map do |row|
          e = eps.find { |rec| rec.id == row["episode_id"] }
          elapsed = Time.now.to_i - row["publish_time"].to_i
          ago =
            if elapsed < 3600
              "#{elapsed / 60} minutes ago".yellow
            elsif elapsed < 86400
              "#{(elapsed / 3600.0).round(1)} hours ago".yellow
            else
              "#{(elapsed / 86400.0).round(1)} days ago".yellow
            end
          puts "    #{e.id}: #{e.title} - #{ago}"
        end
      end
    end

    nil
  end
end
