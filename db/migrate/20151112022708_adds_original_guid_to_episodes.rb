class AddsOriginalGuidToEpisodes < ActiveRecord::Migration[4.2]
  def change
    add_column :episodes, :original_guid, :string
  end
end
