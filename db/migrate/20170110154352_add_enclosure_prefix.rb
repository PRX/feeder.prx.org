class AddEnclosurePrefix < ActiveRecord::Migration[4.2]
  def change
    add_column :podcasts, :enclosure_prefix, :string
  end
end
