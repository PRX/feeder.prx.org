class FixDeletedAtType < ActiveRecord::Migration[4.2]
  def change
    to_delete = ::Episode.deleted.all.collect(&:id)
    remove_column :episodes, :deleted_at
    remove_column :podcasts, :deleted_at

    add_column :episodes, :deleted_at, :timestamp
    add_column :podcasts, :deleted_at, :timestamp

    to_delete.each { |id| ::Episode.with_deleted.find_by_id(id).try(:destroy) }
  end
end
