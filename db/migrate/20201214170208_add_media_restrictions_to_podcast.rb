class AddMediaRestrictionsToPodcast < ActiveRecord::Migration[4.2]
  def change
    add_column :podcasts, :restrictions, :text
  end
end
