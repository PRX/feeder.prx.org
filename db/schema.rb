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

ActiveRecord::Schema.define(version: 20150605224030) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "episodes", force: :cascade do |t|
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "podcast_id"
    t.integer  "prx_id"
    t.text     "overrides"
    t.time     "deleted_at"
  end

  add_index "episodes", ["prx_id"], name: "index_episodes_on_prx_id", unique: true, using: :btree

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

  create_table "podcasts", force: :cascade do |t|
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "title",           null: false
    t.string   "link",            null: false
    t.text     "description"
    t.string   "language"
    t.string   "managing_editor"
    t.datetime "pub_date"
    t.datetime "last_build_date"
    t.string   "categories"
    t.boolean  "explicit"
    t.string   "subtitle"
    t.string   "summary"
    t.string   "keywords"
    t.string   "update_period"
    t.integer  "update_value"
    t.datetime "update_base"
    t.string   "copyright"
    t.string   "author"
    t.string   "owner_name"
    t.string   "owner_email"
    t.integer  "prx_id"
    t.time     "deleted_at"
    t.string   "url"
    t.string   "path"
    t.integer  "max_episodes"
  end

  add_index "podcasts", ["path"], name: "index_podcasts_on_path", unique: true, using: :btree
  add_index "podcasts", ["prx_id"], name: "index_podcasts_on_prx_id", unique: true, using: :btree

end
