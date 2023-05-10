class SetupPodcastImports < ActiveRecord::Migration[7.0]
  def change
    create_table "podcast_imports" do |t|
      t.integer "account_id"
      t.integer "podcast_id"
      t.string "url"
      t.string "status"
      t.integer "feed_episode_count"
      t.text "config"

      t.timestamps
    end

    create_table "episode_imports" do |t|
      t.integer "podcast_import_id"
      t.integer "episode_id"
      t.string "guid"
      t.text "entry"
      t.text "audio"
      t.string "status"
      t.boolean "has_duplicate_guid", default: false

      t.timestamps
    end

    add_foreign_key :podcast_imports, :podcasts
    add_foreign_key :episode_imports, :podcast_imports
  end
end
