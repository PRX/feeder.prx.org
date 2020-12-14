class AddMediaRestrictionToPodcast < ActiveRecord::Migration
  def change
    add_column :podcasts, :restriction, :string
  end
end
