class AddGuidToPodcasts < ActiveRecord::Migration[7.2]
  def change
    add_column :podcasts, :guid, :string
    add_index :podcasts, :guid
  end
end
