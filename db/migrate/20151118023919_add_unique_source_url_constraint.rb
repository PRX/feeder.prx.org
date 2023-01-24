class AddUniqueSourceUrlConstraint < ActiveRecord::Migration[4.2]
  def change
    add_index :podcasts, :source_url, unique: true, where: "deleted_at IS NULL AND source_url IS NOT NULL"
    add_index :episodes, [:original_guid, :podcast_id], unique: true,
      where: "deleted_at IS NULL AND original_guid IS NOT NULL"
  end
end
