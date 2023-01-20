class AddLockedToPodcasts < ActiveRecord::Migration[4.2]
  def up
    remove_column :podcasts, :frozen

    add_column :podcasts, :locked, :boolean, default: false
    execute "UPDATE podcasts SET locked = false"
  end

  def down
    add_column :podcasts, :frozen, :boolean, default: false
    execute "UPDATE podcasts SET frozen = false"

    remove_column :podcasts, :locked
  end
end
