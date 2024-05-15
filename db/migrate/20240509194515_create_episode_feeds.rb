class CreateEpisodeFeeds < ActiveRecord::Migration[7.0]
  include TextSanitizer

  def up
    create_table :episodes_feeds, primary_key: [:episode_id, :feed_id] do |t|
      t.belongs_to :episode
      t.belongs_to :feed
    end

    Feed.includes(:podcast).find_each do |f|
      sql = <<-SQL.squish
        INSERT INTO episodes_feeds
        SELECT id AS episode_id, #{f.id} AS feed_id
        FROM episodes
        WHERE deleted_at IS NULL AND podcast_id = #{f.podcast_id}
      SQL

      if f.include_tags.present?
        kws = f.sanitize_keywords(f.include_tags, true)
        ids = f.podcast.episodes.filter_map do |e|
          e.id if (sanitize_keywords(e.categories, true) & kws).any?
        end
        sql << " AND episodes.id IN (#{ids.concat([0]).join(",")})"
      end

      if f.exclude_tags.present?
        kws = f.sanitize_keywords(f.exclude_tags, true)
        ids = f.podcast.episodes.filter_map do |e|
          e.id if (sanitize_keywords(e.categories, true) & kws).any?
        end
        sql << " AND episodes.id NOT IN (#{ids.join(",")})" if ids.any?
      end

      Feed.connection.execute(sql)
    end
  end

  def down
    drop_table :episodes_feeds
  end
end
