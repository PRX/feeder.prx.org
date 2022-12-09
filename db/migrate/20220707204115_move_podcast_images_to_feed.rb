require 'pry'

class MovePodcastImagesToFeed < ActiveRecord::Migration[4.2]
  TYPES = [FeedImage, ITunesImage].freeze
  FIELDS = %w(guid url link original_url description title format height width size status created_at updated_at).freeze

  def up
    TYPES.each do |klass|
      create_table klass.table_name do |t|
        t.references :feed, index: true, foreign_key: true
        t.string :guid
        t.string :url
        t.string :link
        t.string :original_url
        t.string :description
        t.string :title
        t.string :format
        t.integer :height
        t.integer :width
        t.integer :size
        t.integer :status
        t.timestamps null: false
      end
      add_index klass.table_name, :guid, unique: true
    end

    execute <<-SQL.squish
      INSERT INTO feed_images (feed_id, #{FIELDS.join(', ')})
      SELECT f.id as feed_id, #{FIELDS.map { |f| "i.#{f}" }.join(', ')}
      FROM podcast_images i
      LEFT JOIN feeds f ON (i.podcast_id = f.podcast_id)
      WHERE i.type = 'FeedImage'
      AND f.slug IS NULL
    SQL

    execute <<-SQL.squish
      INSERT INTO itunes_images (feed_id, #{FIELDS.join(', ')})
      SELECT f.id as feed_id, #{FIELDS.map { |f| "i.#{f}" }.join(', ')}
      FROM podcast_images i
      LEFT JOIN feeds f ON (i.podcast_id = f.podcast_id)
      WHERE i.type = 'ITunesImage'
      AND f.slug IS NULL
    SQL

    drop_table :podcast_images
  end

  def down
    create_table :podcast_images do |t|
      t.integer :podcast_id
      t.string :type
      t.string :guid
      t.string :url
      t.string :link
      t.string :original_url
      t.string :description
      t.string :title
      t.string :format
      t.integer :height
      t.integer :width
      t.integer :size
      t.integer :status
      t.timestamps
    end
    add_index :podcast_images, [:guid], name: :index_podcast_images_on_guid, unique: true
    add_index :podcast_images, [:podcast_id], name: :index_podcast_images_on_podcast_id

    execute <<-SQL.squish
      INSERT INTO podcast_images (podcast_id, type, #{FIELDS.join(', ')})
      SELECT p.id as podcast_id, 'FeedImage', #{FIELDS.map { |f| "i.#{f}" }.join(', ')}
      FROM feed_images i
      LEFT JOIN feeds f ON (i.feed_id = f.id)
      LEFT JOIN podcasts p ON (f.podcast_id = p.id)
      WHERE f.slug IS NULL
    SQL

    execute <<-SQL.squish
      INSERT INTO podcast_images (podcast_id, type, #{FIELDS.join(', ')})
      SELECT p.id as podcast_id, 'ITunesImage', #{FIELDS.map { |f| "i.#{f}" }.join(', ')}
      FROM itunes_images i
      LEFT JOIN feeds f ON (i.feed_id = f.id)
      LEFT JOIN podcasts p ON (f.podcast_id = p.id)
      WHERE f.slug IS NULL
    SQL

    drop_table :feed_images
    drop_table :itunes_images
  end
end
