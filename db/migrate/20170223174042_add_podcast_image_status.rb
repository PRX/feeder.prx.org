class AddPodcastImageStatus < ActiveRecord::Migration
  def up
    add_column :podcast_images, :status, :integer
    add_column :podcast_images, :created_at, :datetime
    add_column :podcast_images, :updated_at, :datetime
    execute 'UPDATE podcast_images set created_at = now(), updated_at = now(), status = 3'
  end

  def down
    remove_column :podcast_images, :status
    remove_column :podcast_images, :created_at
    remove_column :podcast_images, :updated_at
  end
end
