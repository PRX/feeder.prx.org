class AddPrefixToPodcasts < ActiveRecord::Migration
  def change
    add_column :podcasts, :enclosure_template, :string
  end
end
