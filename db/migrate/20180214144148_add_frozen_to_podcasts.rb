class AddFrozenToPodcasts < ActiveRecord::Migration[4.2]
  def up
    add_column :podcasts, :frozen, :boolean, default: false
    execute "UPDATE podcasts SET frozen = false"
  end

  def down
    remove_column :podcasts, :frozen
  end
end
