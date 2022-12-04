class AddEpisodeLimitToPodcasts < ActiveRecord::Migration[4.2]
  def change
    add_column :podcasts, :max_episodes, :integer
  end
end
