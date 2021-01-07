class AddMediaRestrictionsToPodcast < ActiveRecord::Migration
  def change
    add_column :podcasts, :restrictions, :text
  end
end
