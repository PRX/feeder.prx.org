class AddEpisodeReleasedAt < ActiveRecord::Migration[4.2]
  def change
    add_column :episodes, :released_at, :datetime
  end
end
