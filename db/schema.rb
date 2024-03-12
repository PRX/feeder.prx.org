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

ActiveRecord::Schema[7.0].define(version: 2024_02_06_213452) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"
  enable_extension "uuid-ossp"

  create_table "apple_configs", force: :cascade do |t|
    t.bigint "public_feed_id", null: false
    t.bigint "private_feed_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "publish_enabled", default: false, null: false
    t.boolean "sync_blocks_rss", default: false, null: false
    t.bigint "key_id"
    t.integer "podcast_id"
    t.index ["key_id"], name: "index_apple_configs_on_key_id"
    t.index ["podcast_id"], name: "index_apple_configs_on_podcast_id", unique: true
    t.index ["private_feed_id"], name: "index_apple_configs_on_private_feed_id"
    t.index ["public_feed_id"], name: "index_apple_configs_on_public_feed_id"
  end

  create_table "apple_episode_delivery_statuses", force: :cascade do |t|
    t.bigint "episode_id", null: false
    t.boolean "delivered", default: false
    t.datetime "created_at", null: false
    t.string "source_url"
    t.string "source_filename"
    t.bigint "source_size"
    t.text "enclosure_url"
    t.integer "source_fetch_count", default: 0
    t.bigint "source_media_version_id"
    t.index ["episode_id", "created_at", "delivered", "id"], name: "index_apple_episode_delivery_statuses_on_episode_id_created_at"
    t.index ["episode_id"], name: "index_apple_episode_delivery_statuses_on_episode_id"
  end

  create_table "apple_keys", force: :cascade do |t|
    t.string "provider_id"
    t.string "key_id"
    t.text "key_pem_b64"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "apple_podcast_containers", force: :cascade do |t|
    t.integer "episode_id"
    t.string "external_id"
    t.string "api_response"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "vendor_id", null: false
    t.string "apple_episode_id", null: false
    t.string "source_url"
    t.string "source_filename"
    t.bigint "source_size"
    t.text "enclosure_url"
    t.integer "source_fetch_count", default: 0, null: false
    t.index ["episode_id"], name: "index_apple_podcast_containers_on_episode_id", unique: true
    t.index ["external_id"], name: "index_apple_podcast_containers_on_external_id", unique: true
  end

  create_table "apple_podcast_deliveries", force: :cascade do |t|
    t.integer "episode_id"
    t.integer "podcast_container_id"
    t.string "external_id"
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "deleted_at", precision: nil
    t.index ["episode_id"], name: "index_apple_podcast_deliveries_on_episode_id"
    t.index ["external_id"], name: "index_apple_podcast_deliveries_on_external_id", unique: true
    t.index ["podcast_container_id"], name: "index_apple_podcast_deliveries_on_podcast_container_id"
  end

  create_table "apple_podcast_delivery_files", force: :cascade do |t|
    t.integer "episode_id"
    t.integer "podcast_delivery_id"
    t.string "external_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "api_marked_as_uploaded", default: false
    t.boolean "upload_operations_complete", default: false
    t.datetime "deleted_at", precision: nil
    t.index ["external_id"], name: "index_apple_podcast_delivery_files_on_external_id", unique: true
    t.index ["podcast_delivery_id"], name: "index_apple_podcast_delivery_files_on_podcast_delivery_id"
  end

  create_table "episode_images", id: :serial, force: :cascade do |t|
    t.integer "episode_id"
    t.string "type"
    t.integer "status"
    t.string "guid"
    t.string "url"
    t.string "original_url"
    t.string "format"
    t.integer "height"
    t.integer "width"
    t.integer "size"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.string "alt_text"
    t.string "caption"
    t.string "credit"
    t.datetime "deleted_at", precision: nil
    t.datetime "replaced_at", precision: nil
    t.index ["episode_id"], name: "index_episode_images_on_episode_id"
    t.index ["guid"], name: "index_episode_images_on_guid", unique: true
  end

  create_table "episode_imports", force: :cascade do |t|
    t.integer "podcast_import_id"
    t.integer "episode_id"
    t.string "guid"
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "type"
    t.text "config"
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
    t.text "production_notes"
    t.integer "medium"
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
    t.string "original_url"
    t.string "format"
    t.integer "height"
    t.integer "width"
    t.integer "size"
    t.integer "status"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.string "alt_text"
    t.string "caption"
    t.string "credit"
    t.datetime "deleted_at", precision: nil
    t.datetime "replaced_at", precision: nil
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
    t.text "subtitle"
    t.text "description"
    t.text "summary"
    t.boolean "include_podcast_value", default: true
    t.boolean "include_donation_url", default: true
    t.text "exclude_tags"
    t.datetime "deleted_at", precision: nil
    t.index ["podcast_id", "slug"], name: "index_feeds_on_podcast_id_and_slug", unique: true, where: "(slug IS NOT NULL)"
    t.index ["podcast_id"], name: "index_feeds_on_podcast_id"
    t.index ["podcast_id"], name: "index_feeds_on_podcast_id_default", unique: true, where: "(slug IS NULL)"
  end

  create_table "itunes_categories", id: :serial, force: :cascade do |t|
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.string "name", null: false
    t.string "subcategories"
    t.integer "feed_id"
  end

  create_table "itunes_images", id: :serial, force: :cascade do |t|
    t.integer "feed_id"
    t.string "guid"
    t.string "url"
    t.string "original_url"
    t.string "format"
    t.integer "height"
    t.integer "width"
    t.integer "size"
    t.integer "status"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.string "alt_text"
    t.string "caption"
    t.string "credit"
    t.datetime "deleted_at", precision: nil
    t.datetime "replaced_at", precision: nil
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
    t.datetime "deleted_at", precision: nil
    t.text "segmentation"
    t.index ["episode_id"], name: "index_media_resources_on_episode_id"
    t.index ["guid"], name: "index_media_resources_on_guid", unique: true
    t.index ["original_url"], name: "index_media_resources_on_original_url"
  end

  create_table "media_version_resources", force: :cascade do |t|
    t.bigint "media_version_id", null: false
    t.bigint "media_resource_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["media_resource_id"], name: "index_media_version_resources_on_media_resource_id"
    t.index ["media_version_id"], name: "index_media_version_resources_on_media_version_id"
  end

  create_table "media_versions", force: :cascade do |t|
    t.bigint "episode_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["episode_id"], name: "index_media_versions_on_episode_id"
  end

  create_table "podcast_imports", force: :cascade do |t|
    t.integer "podcast_id"
    t.string "url"
    t.string "status"
    t.integer "feed_episode_count"
    t.text "config"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "type"
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

  create_table "publishing_pipeline_states", force: :cascade do |t|
    t.bigint "podcast_id", null: false
    t.bigint "publishing_queue_item_id", null: false
    t.integer "status", default: 0, null: false
    t.datetime "created_at", null: false
    t.index ["podcast_id", "publishing_queue_item_id", "status"], name: "index_publishing_pipeline_state_on_unique_status", unique: true, where: "(status = ANY (ARRAY[4, 5, 6, 0, 1]))"
    t.index ["podcast_id", "publishing_queue_item_id", "status"], name: "index_publishing_pipeline_state_uniqueness"
    t.index ["podcast_id", "publishing_queue_item_id", "status"], name: "index_state_on_podcast_queue_item_and_status"
    t.index ["podcast_id"], name: "index_publishing_pipeline_states_on_podcast_id"
    t.index ["publishing_queue_item_id"], name: "index_publishing_pipeline_states_on_publishing_queue_item_id"
  end

  create_table "publishing_queue_items", force: :cascade do |t|
    t.bigint "podcast_id", null: false
    t.integer "last_pipeline_state"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["podcast_id", "created_at"], name: "index_publishing_queue_items_on_podcast_id_and_created_at"
    t.index ["podcast_id"], name: "index_publishing_queue_items_on_podcast_id"
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

  create_table "sessions", force: :cascade do |t|
    t.string "session_id", null: false
    t.text "data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["session_id"], name: "index_sessions_on_session_id", unique: true
    t.index ["updated_at"], name: "index_sessions_on_updated_at"
  end

  create_table "sync_logs", force: :cascade do |t|
    t.string "feeder_type", null: false
    t.bigint "feeder_id", null: false
    t.string "external_id", null: false
    t.datetime "updated_at"
    t.datetime "created_at"
    t.text "api_response"
    t.index ["feeder_type", "feeder_id"], name: "index_sync_logs_on_feeder_type_and_feeder_id", unique: true
  end

  create_table "tasks", id: :serial, force: :cascade do |t|
    t.integer "owner_id"
    t.string "owner_type"
    t.string "type"
    t.integer "status", default: 0, null: false
    t.datetime "logged_at", precision: nil
    t.string "job_id"
    t.text "options"
    t.text "result"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["job_id"], name: "index_tasks_on_job_id"
    t.index ["owner_type", "owner_id"], name: "index_tasks_on_owner_type_and_owner_id"
    t.index ["status"], name: "index_tasks_on_status"
  end

  add_foreign_key "apple_configs", "feeds", column: "private_feed_id"
  add_foreign_key "apple_configs", "feeds", column: "public_feed_id"
  add_foreign_key "apple_episode_delivery_statuses", "episodes"
  add_foreign_key "episode_imports", "podcast_imports"
  add_foreign_key "feed_images", "feeds"
  add_foreign_key "feed_tokens", "feeds"
  add_foreign_key "feeds", "podcasts"
  add_foreign_key "itunes_images", "feeds"
  add_foreign_key "media_version_resources", "media_resources"
  add_foreign_key "media_version_resources", "media_versions"
  add_foreign_key "media_versions", "episodes"
  add_foreign_key "podcast_imports", "podcasts"
  add_foreign_key "publishing_pipeline_states", "podcasts"
  add_foreign_key "publishing_pipeline_states", "publishing_queue_items"
  add_foreign_key "publishing_queue_items", "podcasts"
end
