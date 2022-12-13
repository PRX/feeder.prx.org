class AddCompleteToPodcasts < ActiveRecord::Migration[4.2]
  def change
    add_column :podcasts, :complete, :boolean
  end
end
