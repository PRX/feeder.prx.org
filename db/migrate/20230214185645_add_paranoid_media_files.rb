class AddParanoidMediaFiles < ActiveRecord::Migration[7.0]
  def change
    add_column :episode_images, :deleted_at, :timestamp
    add_column :feed_images, :deleted_at, :timestamp
    add_column :itunes_images, :deleted_at, :timestamp
    add_column :media_resources, :deleted_at, :timestamp

    # also track if media was replaced at the time of deletion
    add_column :episode_images, :replaced_at, :timestamp
    add_column :feed_images, :replaced_at, :timestamp
    add_column :itunes_images, :replaced_at, :timestamp
    add_column :media_resources, :replaced_at, :timestamp

    # feeds must also be paranoid, since they have image assocations
    add_column :feeds, :deleted_at, :timestamp
  end
end
