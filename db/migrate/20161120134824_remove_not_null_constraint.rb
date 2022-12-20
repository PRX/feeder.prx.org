class RemoveNotNullConstraint < ActiveRecord::Migration[4.2]
  def change
    change_column :podcasts, :title, :string, null: true
    change_column :podcasts, :link, :string, null: true
  end
end
