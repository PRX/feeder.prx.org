class AddPodcastsPublishedAt < ActiveRecord::Migration
  def change
    add_column :podcasts, :published_at, :datetime
    execute 'update podcasts set published_at = created_at'
  end
end
