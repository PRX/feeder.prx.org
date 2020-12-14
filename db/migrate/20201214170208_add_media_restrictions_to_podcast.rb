class AddMediaRestrictionsToPodcast < ActiveRecord::Migration
  def change
    add_column :podcasts, :restrictions, :string
  end
end
