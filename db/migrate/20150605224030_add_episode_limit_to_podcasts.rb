class AddEpisodeLimitToPodcasts < ActiveRecord::Migration
  def change
    add_column :podcasts, :max_episodes, :integer
  end
end
