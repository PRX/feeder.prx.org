# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.0].define(version: 2022_09_28_174716) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "episode_images", id: :serial, force: :cascade do |t|
    t.integer "episode_id"
    t.string "type"
    t.integer "status"
    t.string "guid"
    t.string "url"
    t.string "link"
    t.string "original_url"
    t.string "description"
    t.string "title"
    t.string "format"
    t.integer "height"
    t.integer "width"
    t.integer "size"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["episode_id"], name: "index_episode_images_on_episode_id"
    t.index ["guid"], name: "index_episode_images_on_guid", unique: true
  end

  create_table "episodes", id: :serial, force: :cascade do |t|
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.integer "podcast_id"
    t.text "overrides"
    t.string "guid"
    t.string "prx_uri"
    t.datetime "deleted_at", precision: nil
    t.string "original_guid"
    t.datetime "published_at", precision: nil
    t.string "url"
    t.string "author_name"
    t.string "author_email"
    t.text "title"
    t.text "subtitle"
    t.text "content"
    t.text "summary"
    t.string "explicit"
    t.text "keywords"
    t.text "description"
    t.text "categories"
    t.boolean "block"
    t.boolean "is_closed_captioned"
    t.integer "position"
    t.string "feedburner_orig_link"
    t.string "feedburner_orig_enclosure_link"
    t.boolean "is_perma_link"
    t.datetime "source_updated_at", precision: nil
    t.string "keyword_xid"
    t.integer "season_number"
    t.integer "episode_number"
    t.string "itunes_type", default: "full"
    t.text "clean_title"
    t.boolean "itunes_block", default: false
    t.datetime "released_at", precision: nil
    t.string "prx_audio_version_uri"
    t.string "audio_version"
    t.integer "segment_count"
    t.index ["guid"], name: "index_episodes_on_guid", unique: true
    t.index ["keyword_xid"], name: "index_episodes_on_keyword_xid", unique: true
    t.index ["original_guid", "podcast_id"], name: "index_episodes_on_original_guid_and_podcast_id", unique: true, where: "((deleted_at IS NULL) AND (original_guid IS NOT NULL))"
    t.index ["prx_uri"], name: "index_episodes_on_prx_uri", unique: true
    t.index ["published_at", "podcast_id"], name: "index_episodes_on_published_at_and_podcast_id"
  end

  create_table "feed_images", id: :serial, force: :cascade do |t|
    t.integer "feed_id"
    t.string "guid"
    t.string "url"
    t.string "link"
    t.string "original_url"
    t.string "description"
    t.string "title"
    t.string "format"
    t.integer "height"
    t.integer "width"
    t.integer "size"
    t.integer "status"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["feed_id"], name: "index_feed_images_on_feed_id"
    t.index ["guid"], name: "index_feed_images_on_guid", unique: true
  end

  create_table "feed_tokens", id: :serial, force: :cascade do |t|
    t.integer "feed_id"
    t.string "label"
    t.string "token", null: false
    t.datetime "expires_at", precision: nil
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["feed_id", "token"], name: "index_feed_tokens_on_feed_id_and_token", unique: true
    t.index ["feed_id"], name: "index_feed_tokens_on_feed_id"
  end

  create_table "feeds", id: :serial, force: :cascade do |t|
    t.integer "podcast_id"
    t.string "slug"
    t.string "file_name", null: false
    t.boolean "private", default: true
    t.text "title"
    t.string "url"
    t.string "new_feed_url"
    t.integer "display_episodes_count"
    t.integer "display_full_episodes_count"
    t.integer "episode_offset_seconds"
    t.text "include_zones"
    t.text "include_tags"
    t.text "audio_format"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.string "enclosure_prefix"
    t.string "enclosure_template"
    t.text "exclude_tags"
    t.text "subtitle"
    t.text "description"
    t.text "summary"
    t.boolean "include_podcast_value", default: true
    t.boolean "include_donation_url", default: true
    t.index ["podcast_id", "slug"], name: "index_feeds_on_podcast_id_and_slug", unique: true, where: "(slug IS NOT NULL)"
    t.index ["podcast_id"], name: "index_feeds_on_podcast_id"
    t.index ["podcast_id"], name: "index_feeds_on_podcast_id_default", unique: true, where: "(slug IS NULL)"
  end

  create_table "itunes_categories", id: :serial, force: :cascade do |t|
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.integer "podcast_id"
    t.string "name", null: false
    t.string "subcategories"
  end

  create_table "itunes_images", id: :serial, force: :cascade do |t|
    t.integer "feed_id"
    t.string "guid"
    t.string "url"
    t.string "link"
    t.string "original_url"
    t.string "description"
    t.string "title"
    t.string "format"
    t.integer "height"
    t.integer "width"
    t.integer "size"
    t.integer "status"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["feed_id"], name: "index_itunes_images_on_feed_id"
    t.index ["guid"], name: "index_itunes_images_on_guid", unique: true
  end

  create_table "media_resources", id: :serial, force: :cascade do |t|
    t.integer "episode_id"
    t.integer "position"
    t.string "type"
    t.string "url"
    t.string "mime_type"
    t.integer "file_size"
    t.boolean "is_default"
    t.string "medium"
    t.string "expression"
    t.integer "bit_rate"
    t.integer "frame_rate"
    t.decimal "sample_rate"
    t.integer "channels"
    t.decimal "duration"
    t.integer "height"
    t.integer "width"
    t.string "lang"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.string "original_url"
    t.string "guid"
    t.integer "status"
    t.index ["episode_id"], name: "index_media_resources_on_episode_id"
    t.index ["guid"], name: "index_media_resources_on_guid", unique: true
    t.index ["original_url"], name: "index_media_resources_on_original_url"
  end

  create_table "podcasts", id: :serial, force: :cascade do |t|
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.text "title"
    t.string "link"
    t.string "language"
    t.string "managing_editor_name"
    t.string "categories"
    t.string "keywords"
    t.string "update_period"
    t.integer "update_frequency"
    t.datetime "update_base", precision: nil
    t.string "copyright"
    t.string "author_name"
    t.string "owner_name"
    t.string "owner_email"
    t.string "path"
    t.integer "max_episodes"
    t.string "prx_uri"
    t.string "author_email"
    t.string "source_url"
    t.boolean "complete"
    t.string "feedburner_url"
    t.datetime "deleted_at", precision: nil
    t.string "managing_editor_email"
    t.decimal "duration_padding"
    t.string "explicit"
    t.string "prx_account_uri"
    t.datetime "published_at", precision: nil
    t.datetime "source_updated_at", precision: nil
    t.boolean "serial_order", default: false
    t.boolean "locked", default: false
    t.boolean "itunes_block", default: false
    t.text "restrictions"
    t.string "payment_pointer"
    t.string "donation_url"
    t.index ["path"], name: "index_podcasts_on_path", unique: true
    t.index ["prx_uri"], name: "index_podcasts_on_prx_uri", unique: true
    t.index ["source_url"], name: "index_podcasts_on_source_url", unique: true, where: "((deleted_at IS NULL) AND (source_url IS NOT NULL))"
  end

  create_table "say_when_job_executions", id: :serial, force: :cascade do |t|
    t.integer "job_id"
    t.string "status"
    t.text "result"
    t.datetime "start_at", precision: nil
    t.datetime "end_at", precision: nil
    t.index ["job_id"], name: "index_say_when_job_executions_on_job_id"
    t.index ["status", "start_at", "end_at"], name: "index_say_when_job_executions_on_status_and_start_at_and_end_at"
  end

  create_table "say_when_jobs", id: :serial, force: :cascade do |t|
    t.string "group"
    t.string "name"
    t.string "status"
    t.string "trigger_strategy"
    t.text "trigger_options"
    t.datetime "last_fire_at", precision: nil
    t.datetime "next_fire_at", precision: nil
    t.datetime "start_at", precision: nil
    t.datetime "end_at", precision: nil
    t.string "job_class"
    t.string "job_method"
    t.text "data"
    t.string "scheduled_type"
    t.integer "scheduled_id"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["next_fire_at", "status"], name: "index_say_when_jobs_on_next_fire_at_and_status"
    t.index ["scheduled_type", "scheduled_id"], name: "index_say_when_jobs_on_scheduled_type_and_scheduled_id"
  end

  create_table "tasks", id: :serial, force: :cascade do |t|
    t.string "owner_type"
    t.integer "owner_id"
    t.string "type"
    t.integer "status", default: 0, null: false
    t.datetime "logged_at", precision: nil
    t.string "job_id"
    t.text "options"
    t.text "result"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["job_id"], name: "index_tasks_on_job_id"
    t.index ["owner_type", "owner_id"], name: "index_tasks_on_owner"
    t.index ["status"], name: "index_tasks_on_status"
  end

  add_foreign_key "feed_images", "feeds"
  add_foreign_key "feed_tokens", "feeds"
  add_foreign_key "feeds", "podcasts"
  add_foreign_key "itunes_images", "feeds"
end
