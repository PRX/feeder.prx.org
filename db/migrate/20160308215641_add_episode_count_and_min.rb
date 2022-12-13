class AddEpisodeCountAndMin < ActiveRecord::Migration[4.2]
  def change
    add_column :podcasts, :display_episodes_count, :integer
    add_column :podcasts, :display_full_episodes_count, :integer
  end
end
