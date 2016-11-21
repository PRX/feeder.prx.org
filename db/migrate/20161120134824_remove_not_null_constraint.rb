class RemoveNotNullConstraint < ActiveRecord::Migration
  def change
    change_column :podcasts, :title, :string, null: true
    change_column :podcasts, :link, :string, null: true
  end
end
