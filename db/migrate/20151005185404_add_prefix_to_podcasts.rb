class AddPrefixToPodcasts < ActiveRecord::Migration[4.2]
  def change
    add_column :podcasts, :enclosure_template, :string
  end
end
