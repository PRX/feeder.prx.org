class AddLockedUntil < ActiveRecord::Migration[7.1]
  def up
    add_column :podcasts, :locked_until, :timestamp
    Podcast.where(locked: true).update_all(locked_until: "3000-01-01")
  end

  def down
    Podcast.where(locked_until: ..Time.now).update_all(locked: true)
    remove_column :podcasts, :locked_until
  end
end
