class AddPodcastsPublishedAt < ActiveRecord::Migration[4.2]
  def up
    add_column :podcasts, :published_at, :datetime
    execute "update podcasts set published_at = created_at"
  end

  def down
    remove_column :podcasts, :published_at
  end
end
