class AddLockedUntil < ActiveRecord::Migration[7.1]
  def up
    add_column :podcasts, :locked_until, :timestamp
    Podcast.where(locked: true).update_all(locked_until: "3000-01-01")
    remove_column :podcasts, :locked
  end

  def down
    add_column :podcasts, :locked, :boolean, default: false
    Podcast.where(locked_until: Time.now..).update_all(locked: true)
    remove_column :podcasts, :locked_until
  end
end
