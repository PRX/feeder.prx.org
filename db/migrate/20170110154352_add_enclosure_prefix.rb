class AddEnclosurePrefix < ActiveRecord::Migration
  def change
    add_column :podcasts, :enclosure_prefix, :string
  end
end
