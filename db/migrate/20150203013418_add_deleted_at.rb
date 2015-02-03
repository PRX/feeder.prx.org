class AddDeletedAt < ActiveRecord::Migration
  def change
    add_column :episodes, :deleted_at, :time
    add_column :podcasts, :deleted_at, :time
  end
end
