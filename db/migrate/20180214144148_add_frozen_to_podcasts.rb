class AddFrozenToPodcasts < ActiveRecord::Migration
  def change
    add_column :podcasts, :frozen, :boolean, default: false
  end
end
