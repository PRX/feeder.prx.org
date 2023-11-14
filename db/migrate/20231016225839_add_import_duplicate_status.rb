class AddImportDuplicateStatus < ActiveRecord::Migration[7.0]
  def up
    EpisodeImport.where(has_duplicate_guid: true).update_all(status: "duplicate")
    remove_column :episode_imports, :has_duplicate_guid
  end

  def down
    add_column :episode_imports, :has_duplicate_guid, :boolean, default: false
    EpisodeImport.where(status: "duplicate").update_all(has_duplicate_guid: true, status: "error")
  end
end
