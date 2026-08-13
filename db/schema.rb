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

ActiveRecord::Schema[8.1].define(version: 2026_08_05_000002) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "uuid-ossp"

  create_table "apple_configs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "feed_id", null: false
    t.bigint "key_id"
    t.boolean "publish_enabled", default: false, null: false
    t.bigint "show_feed_binding_id"
    t.boolean "sync_blocks_rss", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["feed_id"], name: "index_apple_configs_on_feed_id"
    t.index ["key_id"], name: "index_apple_configs_on_key_id"
    t.index ["show_feed_binding_id"], name: "index_apple_configs_on_show_feed_binding_id"
  end

  create_table "apple_keys", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.datetime "created_at", null: false
    t.string "key_id"
    t.text "key_pem_b64"
    t.string "provider_id"
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_apple_keys_on_account_id"
  end

  create_table "apple_podcast_containers", force: :cascade do |t|
    t.string "api_response"
    t.string "apple_episode_id", null: false
    t.string "apple_show_id"
    t.datetime "created_at", null: false
    t.integer "episode_id"
    t.string "external_id"
    t.datetime "updated_at", null: false
    t.string "vendor_id", null: false
    t.index ["apple_show_id"], name: "index_apple_podcast_containers_on_apple_show_id"
    t.index ["episode_id", "apple_show_id"], name: "idx_apple_podcast_containers_episode_show_unique", unique: true
    t.index ["episode_id"], name: "idx_apple_podcast_containers_legacy_episode_unique", unique: true, where: "(apple_show_id IS NULL)"
    t.index ["external_id"], name: "index_apple_podcast_containers_on_external_id", unique: true
  end

  create_table "apple_podcast_deliveries", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "deleted_at", precision: nil
    t.integer "episode_id"
    t.string "external_id"
    t.integer "podcast_container_id"
    t.string "status"
    t.datetime "updated_at", null: false
    t.index ["episode_id"], name: "index_apple_podcast_deliveries_on_episode_id"
    t.index ["external_id"], name: "index_apple_podcast_deliveries_on_external_id", unique: true
    t.index ["podcast_container_id"], name: "index_apple_podcast_deliveries_on_podcast_container_id"
  end

  create_table "apple_podcast_delivery_files", force: :cascade do |t|
    t.boolean "api_marked_as_uploaded", default: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at", precision: nil
    t.integer "episode_id"
    t.string "external_id"
    t.integer "podcast_delivery_id"
    t.datetime "updated_at", null: false
    t.boolean "upload_operations_complete", default: false
    t.index ["external_id"], name: "index_apple_podcast_delivery_files_on_external_id", unique: true
    t.index ["podcast_delivery_id"], name: "index_apple_podcast_delivery_files_on_podcast_delivery_id"
  end

  create_table "apple_show_feed_bindings", force: :cascade do |t|
    t.string "apple_show_id", null: false
    t.datetime "created_at", null: false
    t.bigint "feed_id", null: false
    t.datetime "updated_at", null: false
    t.index ["feed_id"], name: "index_apple_show_feed_bindings_on_feed_id", unique: true
  end

  create_table "episode_images", id: :serial, force: :cascade do |t|
    t.string "alt_text"
    t.string "caption"
    t.datetime "created_at", precision: nil, null: false
    t.string "credit"
    t.datetime "deleted_at", precision: nil
    t.integer "episode_id"
    t.string "format"
    t.string "guid"
    t.integer "height"
    t.string "original_url"
    t.datetime "replaced_at", precision: nil
    t.integer "size"
    t.integer "status"
    t.string "type"
    t.datetime "updated_at", precision: nil, null: false
    t.string "url"
    t.integer "width"
    t.index ["episode_id"], name: "index_episode_images_on_episode_id"
    t.index ["guid"], name: "index_episode_images_on_guid", unique: true
  end

  create_table "episode_imports", force: :cascade do |t|
    t.text "config"
    t.datetime "created_at", null: false
    t.integer "episode_id"
    t.string "guid"
    t.integer "podcast_import_id"
    t.string "status"
    t.string "type"
    t.datetime "updated_at", null: false
  end

  create_table "episodes", id: :serial, force: :cascade do |t|
    t.string "audio_version"
    t.string "author_email"
    t.string "author_name"
    t.boolean "block"
    t.string "categories", array: true
    t.text "clean_title"
    t.text "content"
    t.datetime "created_at", precision: nil
    t.datetime "deleted_at", precision: nil
    t.text "description"
    t.boolean "enclosure_override_prefix"
    t.string "enclosure_override_url"
    t.integer "episode_number"
    t.string "explicit"
    t.string "feedburner_orig_enclosure_link"
    t.string "feedburner_orig_link"
    t.datetime "first_rss_published_at", precision: nil
    t.string "guid"
    t.boolean "is_closed_captioned"
    t.boolean "is_perma_link"
    t.boolean "itunes_block", default: false
    t.string "itunes_type", default: "full"
    t.string "keyword_xid"
    t.integer "lock_version", default: 0, null: false
    t.integer "medium"
    t.string "original_guid"
    t.text "overrides"
    t.integer "podcast_id"
    t.integer "position"
    t.text "production_notes"
    t.string "prx_audio_version_uri"
    t.string "prx_uri"
    t.datetime "published_at", precision: nil
    t.datetime "released_at", precision: nil
    t.integer "season_number"
    t.integer "segment_count"
    t.datetime "source_updated_at", precision: nil
    t.text "subtitle"
    t.text "summary"
    t.text "title"
    t.datetime "updated_at", precision: nil
    t.string "url"
    t.index ["categories"], name: "index_episodes_on_categories", using: :gin
    t.index ["guid"], name: "index_episodes_on_guid", unique: true
    t.index ["keyword_xid"], name: "index_episodes_on_keyword_xid", unique: true
    t.index ["original_guid", "podcast_id"], name: "index_episodes_on_original_guid_and_podcast_id", unique: true, where: "((deleted_at IS NULL) AND (original_guid IS NOT NULL))"
    t.index ["prx_uri"], name: "index_episodes_on_prx_uri", unique: true
    t.index ["published_at", "podcast_id"], name: "index_episodes_on_published_at_and_podcast_id"
  end

  create_table "episodes_feeds", primary_key: ["episode_id", "feed_id"], force: :cascade do |t|
    t.bigint "episode_id", null: false
    t.bigint "feed_id", null: false
    t.index ["episode_id"], name: "index_episodes_feeds_on_episode_id"
    t.index ["feed_id"], name: "index_episodes_feeds_on_feed_id"
  end

  create_table "feed_images", id: :serial, force: :cascade do |t|
    t.string "alt_text"
    t.string "caption"
    t.datetime "created_at", precision: nil, null: false
    t.string "credit"
    t.datetime "deleted_at", precision: nil
    t.integer "feed_id"
    t.string "format"
    t.string "guid"
    t.integer "height"
    t.string "original_url"
    t.datetime "replaced_at", precision: nil
    t.integer "size"
    t.integer "status"
    t.datetime "updated_at", precision: nil, null: false
    t.string "url"
    t.integer "width"
    t.index ["feed_id"], name: "index_feed_images_on_feed_id"
    t.index ["guid"], name: "index_feed_images_on_guid", unique: true
  end

  create_table "feed_tokens", id: :serial, force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.datetime "expires_at", precision: nil
    t.integer "feed_id"
    t.string "label"
    t.string "token", null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["feed_id", "token"], name: "index_feed_tokens_on_feed_id_and_token", unique: true
    t.index ["feed_id"], name: "index_feed_tokens_on_feed_id"
  end

  create_table "feeds", id: :serial, force: :cascade do |t|
    t.string "apple_show_id"
    t.string "apple_verify_token"
    t.text "audio_format"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "deleted_at", precision: nil
    t.text "description"
    t.integer "display_episodes_count"
    t.integer "display_full_episodes_count"
    t.boolean "edit_locked"
    t.string "enclosure_prefix"
    t.datetime "enclosure_updated_at", precision: nil
    t.string "episode_footer"
    t.integer "episode_offset_seconds"
    t.text "exclude_tags"
    t.string "file_name", null: false
    t.boolean "import_locked", default: true, null: false
    t.boolean "include_donation_url", default: true
    t.boolean "include_podcast_value", default: true
    t.text "include_tags"
    t.text "include_zones"
    t.text "label"
    t.integer "lock_version", default: 0, null: false
    t.string "new_feed_url"
    t.integer "podcast_id"
    t.boolean "private", default: true
    t.string "slug"
    t.text "subtitle"
    t.text "summary"
    t.text "title"
    t.string "type"
    t.boolean "unique_guids", default: false, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.string "url"
    t.index ["apple_show_id"], name: "index_feeds_on_apple_show_id"
    t.index ["podcast_id", "slug"], name: "index_feeds_on_podcast_id_and_slug", unique: true, where: "(slug IS NOT NULL)"
    t.index ["podcast_id"], name: "index_feeds_on_podcast_id"
    t.index ["podcast_id"], name: "index_feeds_on_podcast_id_default", unique: true, where: "(slug IS NULL)"
  end

  create_table "integrations_episode_delivery_statuses", force: :cascade do |t|
    t.string "apple_show_id"
    t.integer "asset_processing_attempts", default: 0
    t.datetime "created_at", null: false
    t.boolean "delivered", default: false
    t.text "enclosure_url"
    t.bigint "episode_id", null: false
    t.integer "integration"
    t.integer "source_fetch_count", default: 0
    t.string "source_filename"
    t.bigint "source_media_version_id"
    t.bigint "source_size"
    t.string "source_url"
    t.boolean "uploaded", default: false
    t.index ["apple_show_id"], name: "index_integrations_episode_delivery_statuses_on_apple_show_id"
    t.index ["episode_id", "created_at"], name: "index_apple_episode_delivery_statuses_on_episode_id_created_at", include: ["delivered", "id"]
    t.index ["episode_id"], name: "index_integrations_episode_delivery_statuses_on_episode_id"
  end

  create_table "itunes_categories", id: :serial, force: :cascade do |t|
    t.datetime "created_at", precision: nil
    t.integer "feed_id"
    t.string "name", null: false
    t.string "subcategories"
    t.datetime "updated_at", precision: nil
  end

  create_table "itunes_images", id: :serial, force: :cascade do |t|
    t.string "alt_text"
    t.string "caption"
    t.datetime "created_at", precision: nil, null: false
    t.string "credit"
    t.datetime "deleted_at", precision: nil
    t.integer "feed_id"
    t.string "format"
    t.string "guid"
    t.integer "height"
    t.string "original_url"
    t.datetime "replaced_at", precision: nil
    t.integer "size"
    t.integer "status"
    t.datetime "updated_at", precision: nil, null: false
    t.string "url"
    t.integer "width"
    t.index ["feed_id"], name: "index_itunes_images_on_feed_id"
    t.index ["guid"], name: "index_itunes_images_on_guid", unique: true
  end

  create_table "media_resources", id: :serial, force: :cascade do |t|
    t.integer "bit_rate"
    t.integer "channels"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "deleted_at", precision: nil
    t.decimal "duration"
    t.integer "episode_id"
    t.string "expression"
    t.integer "file_size"
    t.integer "frame_rate"
    t.string "guid"
    t.integer "height"
    t.boolean "is_default"
    t.string "lang"
    t.string "medium"
    t.string "mime_type"
    t.string "original_url"
    t.integer "position"
    t.decimal "sample_rate"
    t.text "segmentation"
    t.integer "status"
    t.string "type"
    t.datetime "updated_at", precision: nil, null: false
    t.string "url"
    t.integer "width"
    t.index ["episode_id"], name: "index_media_resources_on_episode_id"
    t.index ["guid"], name: "index_media_resources_on_guid", unique: true
    t.index ["original_url"], name: "index_media_resources_on_original_url"
  end

  create_table "media_version_resources", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "media_resource_id", null: false
    t.bigint "media_version_id", null: false
    t.datetime "updated_at", null: false
    t.index ["media_resource_id"], name: "index_media_version_resources_on_media_resource_id"
    t.index ["media_version_id"], name: "index_media_version_resources_on_media_version_id"
  end

  create_table "media_versions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "episode_id", null: false
    t.datetime "updated_at", null: false
    t.index ["episode_id"], name: "index_media_versions_on_episode_id"
  end

  create_table "megaphone_configs", force: :cascade do |t|
    t.text "advertising_tags"
    t.datetime "created_at", null: false
    t.bigint "feed_id", null: false
    t.string "network_id"
    t.string "network_name"
    t.string "organization_id"
    t.boolean "publish_enabled", default: false, null: false
    t.boolean "sync_blocks_rss", default: false, null: false
    t.string "token"
    t.datetime "updated_at", null: false
  end

  create_table "persons", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "href"
    t.string "name"
    t.string "organization"
    t.bigint "owner_id"
    t.string "owner_type"
    t.string "role"
    t.datetime "updated_at", null: false
    t.index ["owner_type", "owner_id"], name: "index_persons_on_owner"
  end

  create_table "podcast_imports", force: :cascade do |t|
    t.text "config"
    t.datetime "created_at", null: false
    t.integer "feed_episode_count"
    t.integer "podcast_id"
    t.string "status"
    t.string "type"
    t.datetime "updated_at", null: false
    t.string "url"
  end

  create_table "podcasts", id: :serial, force: :cascade do |t|
    t.bigint "apple_key_id"
    t.string "author_email"
    t.string "author_name"
    t.string "categories", array: true
    t.boolean "complete"
    t.string "copyright"
    t.datetime "created_at", precision: nil
    t.datetime "deleted_at", precision: nil
    t.string "donation_url"
    t.decimal "duration_padding"
    t.string "explicit"
    t.string "feedburner_url"
    t.string "guid"
    t.boolean "itunes_block", default: false
    t.string "language"
    t.string "link"
    t.integer "lock_version", default: 0, null: false
    t.datetime "locked_until", precision: nil
    t.string "managing_editor_email"
    t.string "managing_editor_name"
    t.integer "max_episodes"
    t.string "owner_email"
    t.string "owner_name"
    t.string "path"
    t.string "payment_pointer"
    t.string "prx_account_uri"
    t.string "prx_uri"
    t.datetime "published_at", precision: nil
    t.text "restrictions"
    t.boolean "serial_order", default: false
    t.datetime "source_updated_at", precision: nil
    t.string "source_url"
    t.text "title"
    t.datetime "update_base", precision: nil
    t.integer "update_frequency"
    t.string "update_period"
    t.datetime "updated_at", precision: nil
    t.index ["apple_key_id"], name: "index_podcasts_on_apple_key_id"
    t.index ["categories"], name: "index_podcasts_on_categories", using: :gin
    t.index ["guid"], name: "index_podcasts_on_guid"
    t.index ["path"], name: "index_podcasts_on_path", unique: true
    t.index ["prx_uri"], name: "index_podcasts_on_prx_uri", unique: true
    t.index ["source_url"], name: "index_podcasts_on_source_url", unique: true, where: "((deleted_at IS NULL) AND (source_url IS NOT NULL))"
  end

  create_table "publishing_pipeline_states", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "podcast_id", null: false
    t.bigint "publishing_queue_item_id", null: false
    t.integer "status", default: 0, null: false
    t.index ["podcast_id", "publishing_queue_item_id", "status"], name: "index_publishing_pipeline_state_on_unique_status", unique: true, where: "(status = ANY (ARRAY[4, 5, 6, 0, 1]))"
    t.index ["podcast_id", "publishing_queue_item_id", "status"], name: "index_publishing_pipeline_state_uniqueness"
    t.index ["podcast_id", "publishing_queue_item_id", "status"], name: "index_state_on_podcast_queue_item_and_status"
    t.index ["podcast_id"], name: "index_publishing_pipeline_states_on_podcast_id"
    t.index ["publishing_queue_item_id"], name: "index_publishing_pipeline_states_on_publishing_queue_item_id"
  end

  create_table "publishing_queue_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "job_id"
    t.integer "last_pipeline_state"
    t.bigint "podcast_id", null: false
    t.datetime "updated_at", null: false
    t.index ["podcast_id", "created_at"], name: "index_publishing_queue_items_on_podcast_id_and_created_at"
    t.index ["podcast_id"], name: "index_publishing_queue_items_on_podcast_id"
  end

  create_table "say_when_job_executions", id: :serial, force: :cascade do |t|
    t.datetime "end_at", precision: nil
    t.integer "job_id"
    t.text "result"
    t.datetime "start_at", precision: nil
    t.string "status"
    t.index ["job_id"], name: "index_say_when_job_executions_on_job_id"
    t.index ["status", "start_at", "end_at"], name: "index_say_when_job_executions_on_status_and_start_at_and_end_at"
  end

  create_table "say_when_jobs", id: :serial, force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.text "data"
    t.datetime "end_at", precision: nil
    t.string "group"
    t.string "job_class"
    t.string "job_method"
    t.datetime "last_fire_at", precision: nil
    t.string "name"
    t.datetime "next_fire_at", precision: nil
    t.integer "scheduled_id"
    t.string "scheduled_type"
    t.datetime "start_at", precision: nil
    t.string "status"
    t.text "trigger_options"
    t.string "trigger_strategy"
    t.datetime "updated_at", precision: nil, null: false
    t.index ["next_fire_at", "status"], name: "index_say_when_jobs_on_next_fire_at_and_status"
    t.index ["scheduled_type", "scheduled_id"], name: "index_say_when_jobs_on_scheduled_type_and_scheduled_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "data"
    t.string "session_id", null: false
    t.datetime "updated_at", null: false
    t.index ["session_id"], name: "index_sessions_on_session_id", unique: true
    t.index ["updated_at"], name: "index_sessions_on_updated_at"
  end

  create_table "stream_recordings", force: :cascade do |t|
    t.string "create_as"
    t.datetime "created_at", null: false
    t.datetime "deleted_at", precision: nil
    t.date "end_date"
    t.integer "expiration"
    t.integer "lock_version", default: 0, null: false
    t.bigint "podcast_id"
    t.text "record_days"
    t.text "record_hours"
    t.date "start_date"
    t.string "status"
    t.string "time_zone"
    t.datetime "updated_at", null: false
    t.string "url"
    t.index ["podcast_id"], name: "index_stream_recordings_on_podcast_id"
  end

  create_table "stream_resources", force: :cascade do |t|
    t.datetime "actual_end_at", precision: nil
    t.datetime "actual_start_at", precision: nil
    t.integer "bit_rate"
    t.integer "channels"
    t.datetime "created_at", null: false
    t.datetime "deleted_at", precision: nil
    t.decimal "duration"
    t.datetime "end_at", precision: nil
    t.integer "file_size"
    t.string "guid"
    t.string "mime_type"
    t.string "original_url"
    t.decimal "sample_rate"
    t.datetime "start_at", precision: nil
    t.string "status"
    t.bigint "stream_recording_id"
    t.datetime "updated_at", null: false
    t.string "url"
    t.index ["end_at"], name: "index_stream_resources_on_end_at"
    t.index ["start_at"], name: "index_stream_resources_on_start_at"
    t.index ["stream_recording_id"], name: "index_stream_resources_on_stream_recording_id"
  end

  create_table "subscribe_links", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "external_id"
    t.string "platform"
    t.bigint "podcast_id"
    t.datetime "updated_at", null: false
    t.index ["podcast_id"], name: "index_subscribe_links_on_podcast_id"
  end

  create_table "sync_logs", force: :cascade do |t|
    t.text "api_response"
    t.datetime "created_at"
    t.string "external_id", null: false
    t.string "external_show_id"
    t.bigint "feeder_id", null: false
    t.string "feeder_type", null: false
    t.integer "integration"
    t.datetime "updated_at"
    t.index ["integration", "feeder_type", "feeder_id", "external_show_id"], name: "idx_sync_logs_unique_by_external_show", unique: true, nulls_not_distinct: true
  end

  create_table "tasks", id: :serial, force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.string "job_id"
    t.datetime "logged_at", precision: nil
    t.text "options"
    t.integer "owner_id"
    t.string "owner_type"
    t.text "result"
    t.integer "status", default: 0, null: false
    t.string "type"
    t.datetime "updated_at", precision: nil, null: false
    t.index ["job_id"], name: "index_tasks_on_job_id"
    t.index ["owner_type", "owner_id"], name: "index_tasks_on_owner_type_and_owner_id"
    t.index ["status"], name: "index_tasks_on_status"
  end

  create_table "transcripts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "deleted_at", precision: nil
    t.bigint "episode_id"
    t.integer "file_size"
    t.string "format"
    t.string "guid"
    t.string "mime_type"
    t.string "original_url"
    t.integer "status"
    t.datetime "updated_at", null: false
    t.string "url"
    t.index ["episode_id"], name: "index_transcripts_on_episode_id"
    t.index ["guid"], name: "index_transcripts_on_guid", unique: true
  end

  add_foreign_key "apple_configs", "apple_show_feed_bindings", column: "show_feed_binding_id"
  add_foreign_key "apple_configs", "feeds"
  add_foreign_key "apple_show_feed_bindings", "feeds"
  add_foreign_key "episode_imports", "podcast_imports"
  add_foreign_key "feed_images", "feeds"
  add_foreign_key "feed_tokens", "feeds"
  add_foreign_key "feeds", "podcasts"
  add_foreign_key "integrations_episode_delivery_statuses", "episodes"
  add_foreign_key "itunes_images", "feeds"
  add_foreign_key "media_version_resources", "media_resources"
  add_foreign_key "media_version_resources", "media_versions"
  add_foreign_key "media_versions", "episodes"
  add_foreign_key "podcast_imports", "podcasts"
  add_foreign_key "podcasts", "apple_keys"
  add_foreign_key "publishing_pipeline_states", "podcasts"
  add_foreign_key "publishing_pipeline_states", "publishing_queue_items"
  add_foreign_key "publishing_queue_items", "podcasts"
  add_foreign_key "stream_recordings", "podcasts"
  add_foreign_key "stream_resources", "stream_recordings"
end
