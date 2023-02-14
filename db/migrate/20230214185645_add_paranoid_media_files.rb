class AddParanoidMediaFiles < ActiveRecord::Migration[7.0]
  def change
    add_column :episode_images, :deleted_at, :time
    add_column :feed_images, :deleted_at, :time
    add_column :itunes_images, :deleted_at, :time
    add_column :media_resources, :deleted_at, :time

    # feeds must also be paranoid, since they have image assocations
    add_column :feeds, :deleted_at, :time
  end
end
