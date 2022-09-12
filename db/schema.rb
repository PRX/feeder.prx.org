# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20220912144326) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"
  enable_extension "uuid-ossp"

  create_table "apple_podcast_containers", force: :cascade do |t|
    t.integer  "episode_id"
    t.string   "external_id"
    t.string   "api_response"
    t.datetime "created_at",   null: false
    t.datetime "updated_at",   null: false
  end

  add_index "apple_podcast_containers", ["episode_id"], name: "index_apple_podcast_containers_on_episode_id", unique: true, using: :btree

  create_table "apple_podcast_deliveries", force: :cascade do |t|
    t.integer  "episode_id"
    t.string   "external_id"
    t.string   "status"
    t.string   "api_response"
    t.datetime "created_at",   null: false
    t.datetime "updated_at",   null: false
  end

  add_index "apple_podcast_deliveries", ["episode_id"], name: "index_apple_podcast_deliveries_on_episode_id", unique: true, using: :btree

  create_table "episode_images", force: :cascade do |t|
    t.integer  "episode_id"
    t.string   "type"
    t.integer  "status"
    t.string   "guid"
    t.string   "url"
    t.string   "link"
    t.string   "original_url"
    t.string   "description"
    t.string   "title"
    t.string   "format"
    t.integer  "height"
    t.integer  "width"
    t.integer  "size"
    t.datetime "created_at",   null: false
    t.datetime "updated_at",   null: false
  end

  add_index "episode_images", ["episode_id"], name: "index_episode_images_on_episode_id", using: :btree
  add_index "episode_images", ["guid"], name: "index_episode_images_on_guid", unique: true, using: :btree

  create_table "episodes", force: :cascade do |t|
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "podcast_id"
    t.text     "overrides"
    t.string   "guid"
    t.string   "prx_uri"
    t.datetime "deleted_at"
    t.string   "original_guid"
    t.datetime "published_at"
    t.string   "url"
    t.string   "author_name"
    t.string   "author_email"
    t.text     "title"
    t.text     "subtitle"
    t.text     "content"
    t.text     "summary"
    t.string   "explicit"
    t.text     "keywords"
    t.text     "description"
    t.text     "categories"
    t.boolean  "block"
    t.boolean  "is_closed_captioned"
    t.integer  "position"
    t.string   "feedburner_orig_link"
    t.string   "feedburner_orig_enclosure_link"
    t.boolean  "is_perma_link"
    t.datetime "source_updated_at"
    t.string   "keyword_xid"
    t.integer  "season_number"
    t.integer  "episode_number"
    t.string   "itunes_type",                    default: "full"
    t.text     "clean_title"
    t.boolean  "itunes_block",                   default: false
    t.datetime "released_at"
    t.string   "prx_audio_version_uri"
    t.string   "audio_version"
    t.integer  "segment_count"
  end

  add_index "episodes", ["guid"], name: "index_episodes_on_guid", unique: true, using: :btree
  add_index "episodes", ["keyword_xid"], name: "index_episodes_on_keyword_xid", unique: true, using: :btree
  add_index "episodes", ["original_guid", "podcast_id"], name: "index_episodes_on_original_guid_and_podcast_id", unique: true, where: "((deleted_at IS NULL) AND (original_guid IS NOT NULL))", using: :btree
  add_index "episodes", ["prx_uri"], name: "index_episodes_on_prx_uri", unique: true, using: :btree
  add_index "episodes", ["published_at", "podcast_id"], name: "index_episodes_on_published_at_and_podcast_id", using: :btree

  create_table "feed_images", force: :cascade do |t|
    t.string  "url"
    t.string  "link"
    t.string  "description"
    t.integer "height"
    t.integer "width"
    t.integer "podcast_id"
    t.string  "title"
    t.string  "format"
    t.integer "size"
  end

  add_index "feed_images", ["podcast_id"], name: "index_feed_images_on_podcast_id", using: :btree

  create_table "feed_tokens", force: :cascade do |t|
    t.integer  "feed_id"
    t.string   "label"
    t.string   "token",      null: false
    t.datetime "expires_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_index "feed_tokens", ["feed_id", "token"], name: "index_feed_tokens_on_feed_id_and_token", unique: true, using: :btree
  add_index "feed_tokens", ["feed_id"], name: "index_feed_tokens_on_feed_id", using: :btree

  create_table "feeds", force: :cascade do |t|
    t.integer  "podcast_id"
    t.string   "slug"
    t.string   "file_name",                                  null: false
    t.boolean  "private",                     default: true
    t.text     "title"
    t.string   "url"
    t.string   "new_feed_url"
    t.integer  "display_episodes_count"
    t.integer  "display_full_episodes_count"
    t.integer  "episode_offset_seconds"
    t.text     "include_zones"
    t.text     "include_tags"
    t.text     "audio_format"
    t.datetime "created_at",                                 null: false
    t.datetime "updated_at",                                 null: false
    t.string   "enclosure_prefix"
    t.string   "enclosure_template"
    t.text     "exclude_tags"
  end

  add_index "feeds", ["podcast_id", "slug"], name: "index_feeds_on_podcast_id_and_slug", unique: true, where: "(slug IS NOT NULL)", using: :btree
  add_index "feeds", ["podcast_id"], name: "index_feeds_on_podcast_id", using: :btree
  add_index "feeds", ["podcast_id"], name: "index_feeds_on_podcast_id_default", unique: true, where: "(slug IS NULL)", using: :btree

  create_table "itunes_categories", force: :cascade do |t|
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "podcast_id"
    t.string   "name",          null: false
    t.string   "subcategories"
  end

  create_table "itunes_images", force: :cascade do |t|
    t.string  "url"
    t.integer "podcast_id"
    t.string  "format"
    t.integer "width"
    t.integer "height"
    t.integer "size"
  end

  add_index "itunes_images", ["podcast_id"], name: "index_itunes_images_on_podcast_id", using: :btree

  create_table "media_resources", force: :cascade do |t|
    t.integer  "episode_id"
    t.integer  "position"
    t.string   "type"
    t.string   "url"
    t.string   "mime_type"
    t.integer  "file_size"
    t.boolean  "is_default"
    t.string   "medium"
    t.string   "expression"
    t.integer  "bit_rate"
    t.integer  "frame_rate"
    t.decimal  "sample_rate"
    t.integer  "channels"
    t.decimal  "duration"
    t.integer  "height"
    t.integer  "width"
    t.string   "lang"
    t.datetime "created_at",   null: false
    t.datetime "updated_at",   null: false
    t.string   "original_url"
    t.string   "guid"
    t.integer  "status"
  end

  add_index "media_resources", ["episode_id"], name: "index_media_resources_on_episode_id", using: :btree
  add_index "media_resources", ["guid"], name: "index_media_resources_on_guid", unique: true, using: :btree
  add_index "media_resources", ["original_url"], name: "index_media_resources_on_original_url", using: :btree

  create_table "podcast_images", force: :cascade do |t|
    t.integer  "podcast_id"
    t.string   "type"
    t.string   "guid"
    t.string   "url"
    t.string   "link"
    t.string   "original_url"
    t.string   "description"
    t.string   "title"
    t.string   "format"
    t.integer  "height"
    t.integer  "width"
    t.integer  "size"
    t.integer  "status"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "podcast_images", ["guid"], name: "index_podcast_images_on_guid", unique: true, using: :btree
  add_index "podcast_images", ["podcast_id"], name: "index_podcast_images_on_podcast_id", using: :btree

  create_table "podcasts", force: :cascade do |t|
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "title"
    t.string   "link"
    t.text     "description"
    t.string   "language"
    t.string   "managing_editor_name"
    t.string   "categories"
    t.text     "subtitle"
    t.text     "summary"
    t.string   "keywords"
    t.string   "update_period"
    t.integer  "update_frequency"
    t.datetime "update_base"
    t.string   "copyright"
    t.string   "author_name"
    t.string   "owner_name"
    t.string   "owner_email"
    t.string   "path"
    t.integer  "max_episodes"
    t.string   "prx_uri"
    t.string   "author_email"
    t.string   "source_url"
    t.boolean  "complete"
    t.string   "feedburner_url"
    t.datetime "deleted_at"
    t.string   "managing_editor_email"
    t.decimal  "duration_padding"
    t.string   "explicit"
    t.string   "prx_account_uri"
    t.datetime "published_at"
    t.datetime "source_updated_at"
    t.boolean  "serial_order",          default: false
    t.boolean  "locked",                default: false
    t.boolean  "itunes_block",          default: false
    t.text     "restrictions"
  end

  add_index "podcasts", ["path"], name: "index_podcasts_on_path", unique: true, using: :btree
  add_index "podcasts", ["prx_uri"], name: "index_podcasts_on_prx_uri", unique: true, using: :btree
  add_index "podcasts", ["source_url"], name: "index_podcasts_on_source_url", unique: true, where: "((deleted_at IS NULL) AND (source_url IS NOT NULL))", using: :btree

  create_table "say_when_job_executions", force: :cascade do |t|
    t.integer  "job_id"
    t.string   "status"
    t.text     "result"
    t.datetime "start_at"
    t.datetime "end_at"
  end

  add_index "say_when_job_executions", ["job_id"], name: "index_say_when_job_executions_on_job_id", using: :btree
  add_index "say_when_job_executions", ["status", "start_at", "end_at"], name: "index_say_when_job_executions_on_status_and_start_at_and_end_at", using: :btree

  create_table "say_when_jobs", force: :cascade do |t|
    t.string   "group"
    t.string   "name"
    t.string   "status"
    t.string   "trigger_strategy"
    t.text     "trigger_options"
    t.datetime "last_fire_at"
    t.datetime "next_fire_at"
    t.datetime "start_at"
    t.datetime "end_at"
    t.string   "job_class"
    t.string   "job_method"
    t.text     "data"
    t.string   "scheduled_type"
    t.integer  "scheduled_id"
    t.datetime "created_at",       null: false
    t.datetime "updated_at",       null: false
  end

  add_index "say_when_jobs", ["next_fire_at", "status"], name: "index_say_when_jobs_on_next_fire_at_and_status", using: :btree
  add_index "say_when_jobs", ["scheduled_type", "scheduled_id"], name: "index_say_when_jobs_on_scheduled_type_and_scheduled_id", using: :btree

  create_table "sync_logs", force: :cascade do |t|
    t.string   "feeder_type",                 null: false
    t.integer  "feeder_id",         limit: 8, null: false
    t.string   "external_id"
    t.datetime "sync_completed_at"
    t.datetime "created_at"
  end

  create_table "tasks", force: :cascade do |t|
    t.integer  "owner_id"
    t.string   "owner_type"
    t.string   "type"
    t.integer  "status",     default: 0, null: false
    t.datetime "logged_at"
    t.string   "job_id"
    t.text     "options"
    t.text     "result"
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
  end

  add_index "tasks", ["job_id"], name: "index_tasks_on_job_id", using: :btree
  add_index "tasks", ["owner_type", "owner_id"], name: "index_tasks_on_owner_type_and_owner_id", using: :btree
  add_index "tasks", ["status"], name: "index_tasks_on_status", using: :btree

  add_foreign_key "feed_tokens", "feeds"
  add_foreign_key "feeds", "podcasts"
end
