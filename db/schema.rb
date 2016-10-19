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

ActiveRecord::Schema.define(version: 20161014123500) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

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
    t.datetime "released_at"
    t.string   "url"
    t.string   "author_name"
    t.string   "author_email"
    t.text     "title"
    t.text     "subtitle"
    t.text     "content"
    t.text     "summary"
    t.datetime "published"
    t.datetime "updated"
    t.string   "image_url"
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
  end

  add_index "episodes", ["guid"], name: "index_episodes_on_guid", unique: true, using: :btree
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

  create_table "podcasts", force: :cascade do |t|
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "title",                       null: false
    t.string   "link",                        null: false
    t.text     "description"
    t.string   "language"
    t.string   "managing_editor_name"
    t.datetime "pub_date"
    t.datetime "last_build_date"
    t.string   "categories"
    t.string   "subtitle"
    t.string   "summary"
    t.string   "keywords"
    t.string   "update_period"
    t.integer  "update_frequency"
    t.datetime "update_base"
    t.string   "copyright"
    t.string   "author_name"
    t.string   "owner_name"
    t.string   "owner_email"
    t.string   "url"
    t.string   "path"
    t.integer  "max_episodes"
    t.string   "prx_uri"
    t.string   "author_email"
    t.string   "source_url"
    t.boolean  "complete"
    t.string   "feedburner_url"
    t.string   "enclosure_template"
    t.datetime "deleted_at"
    t.string   "managing_editor_email"
    t.decimal  "duration_padding"
    t.integer  "display_episodes_count"
    t.integer  "display_full_episodes_count"
    t.string   "explicit"
  end

  add_index "podcasts", ["path"], name: "index_podcasts_on_path", unique: true, using: :btree
  add_index "podcasts", ["prx_uri"], name: "index_podcasts_on_prx_uri", unique: true, using: :btree
  add_index "podcasts", ["source_url"], name: "index_podcasts_on_source_url", unique: true, where: "((deleted_at IS NULL) AND (source_url IS NOT NULL))", using: :btree

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

end
