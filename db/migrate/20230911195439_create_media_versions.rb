class CreateMediaVersions < ActiveRecord::Migration[7.0]
  def change
    create_table :media_versions do |t|
      t.references :episode, null: false, foreign_key: true
      t.timestamps
    end

    create_table :media_version_resources do |t|
      t.references :media_version, null: false, foreign_key: true
      t.references :media_resource, null: false, foreign_key: true
      t.timestamps
    end
  end
end
