class AddDeletedAt < ActiveRecord::Migration[4.2]
  def change
    add_column :episodes, :deleted_at, :time
    add_column :podcasts, :deleted_at, :time
  end
end
