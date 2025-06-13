class AddEnclosureOverrideUrlToEpisodes < ActiveRecord::Migration[7.2]
  def change
    add_column :episodes, :enclosure_override_url, :string
    add_column :episodes, :enclosure_override_prefix, :boolean
  end
end
