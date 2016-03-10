class AddEpisodeCountAndMin < ActiveRecord::Migration
  def change
    add_column :podcasts, :display_episodes_count, :integer
    add_column :podcasts, :display_full_episodes_count, :integer
  end
end
