class AddCompleteToPodcasts < ActiveRecord::Migration
  def change
    add_column :podcasts, :complete, :boolean
  end
end
