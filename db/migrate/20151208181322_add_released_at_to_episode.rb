class AddReleasedAtToEpisode < ActiveRecord::Migration
  def change
    add_column :episodes, :released_at, :timestamp
  end
end
