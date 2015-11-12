class AddsOriginalGuidToEpisodes < ActiveRecord::Migration
  def change
    add_column :episodes, :original_guid, :string
  end
end
