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

ActiveRecord::Schema.define(version: 20141222182251) do

  create_table "episodes", force: true do |t|
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "podcast_id"
    t.string   "title"
    t.text     "description"
    t.string   "link"
    t.date     "pub_date"
    t.string   "categories"
    t.string   "audio_file"
    t.string   "comments"
    t.string   "subtitle"
    t.text     "summary"
    t.boolean  "explicit"
    t.integer  "duration"
    t.string   "keywords"
    t.string   "author_name"
    t.string   "author_email"
    t.integer  "audio_file_size"
    t.string   "audio_file_type"
    t.integer  "prx_id"
  end

  add_index "episodes", ["prx_id"], name: "index_episodes_on_prx_id", using: :btree

  create_table "images", force: true do |t|
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "title",          null: false
    t.string   "url",            null: false
    t.string   "link",           null: false
    t.integer  "height"
    t.integer  "width"
    t.text     "description"
    t.integer  "imageable_id"
    t.string   "imageable_type"
  end

  create_table "itunes_categories", force: true do |t|
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "podcast_id"
    t.string   "name",          null: false
    t.string   "subcategories"
  end

  create_table "podcasts", force: true do |t|
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
  end

end
