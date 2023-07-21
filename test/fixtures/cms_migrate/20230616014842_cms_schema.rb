class CmsSchema < ActiveRecord::Migration
  def change
    create_table "account_images", force: true do |t|
      t.integer "parent_id"
      t.string "content_type"
      t.string "filename"
      t.string "thumbnail"
      t.integer "size"
      t.integer "width"
      t.integer "height"
      t.float "aspect_ratio"
      t.integer "account_id"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.text "upload_path"
      t.string "status"
      t.string "caption"
      t.string "credit"
      t.string "purpose"
    end

    add_index "account_images", ["account_id"], name: "account_images_account_id_fk"
    add_index "account_images", ["parent_id"], name: "parent_id_idx"
    add_index "account_images", ["updated_at"], name: "index_account_images_on_updated_at"

    create_table "account_memberships", force: true do |t|
      t.date "start_date"
      t.date "end_date"
      t.integer "size_limit"
      t.string "payment_status"
      t.string "payment_type"
      t.integer "price_paid"
      t.integer "account_id"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.text "notes"
    end

    add_index "account_memberships", ["account_id", "start_date", "end_date"], name: "current_membership_idx"
    add_index "account_memberships", ["account_id"], name: "account_id_idx"

    create_table "account_message_types", force: true do |t|
      t.integer "account_id"
      t.string "message_type"
      t.text "user_recipients"
      t.text "email_recipients"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.text "default_recipients"
    end

    create_table "accounts", force: true do |t|
      t.string "type"
      t.string "name"
      t.integer "opener_id"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string "status"
      t.string "station_call_letters"
      t.string "station_frequency"
      t.string "station_coverage_area"
      t.string "contact_phone"
      t.string "contact_email"
      t.integer "contact_id"
      t.datetime "deleted_at"
      t.text "request_description"
      t.text "description"
      t.string "opener_role"
      t.string "intended_uses"
      t.integer "address_id"
      t.datetime "request_licensing_at"
      t.string "contact_first_name"
      t.string "contact_last_name"
      t.string "station_total_revenue"
      t.integer "station_total_revenue_year"
      t.string "planned_programming"
      t.string "path"
      t.string "phone"
      t.datetime "outside_purchaser_at"
      t.boolean "outside_purchaser_default_option"
      t.integer "total_points_earned", default: 0
      t.integer "total_points_spent", default: 0
      t.integer "additional_size_limit", default: 0
      t.string "api_key"
      t.integer "npr_org_id"
      t.string "delivery_ftp_password"
      t.string "stripe_customer_token"
      t.string "card_type"
      t.integer "card_last_four"
      t.integer "card_exp_month"
      t.integer "card_exp_year"
      t.string "short_name"
      t.string "delivery_ftp_user"
    end

    add_index "accounts", ["api_key"], name: "index_accounts_on_api_key"
    add_index "accounts", ["contact_id"], name: "accounts_contact_id_fk"
    add_index "accounts", ["deleted_at"], name: "deleted_at_idx"
    add_index "accounts", ["opener_id"], name: "accounts_opener_id_fk"
    add_index "accounts", ["outside_purchaser_at"], name: "outside_purchaser_at_idx"
    add_index "accounts", ["path"], name: "path_idx"
    add_index "accounts", ["status"], name: "status_idx"

    create_table "addresses", force: true do |t|
      t.integer "addressable_id"
      t.string "addressable_type"
      t.string "street_1"
      t.string "street_2"
      t.string "street_3"
      t.string "postal_code"
      t.string "city"
      t.string "state"
      t.string "country"
      t.datetime "created_at"
      t.datetime "updated_at"
    end

    add_index "addresses", ["addressable_type", "addressable_id"], name: "index_addresses_on_addressable_type_and_addressable_id"
    add_index "addresses", ["updated_at"], name: "index_addresses_on_updated_at"

    create_table "affiliations", force: true do |t|
      t.integer "affiliable_id"
      t.string "affiliable_type"
      t.string "name"
    end

    create_table "alerts", force: true do |t|
      t.string "type"
      t.integer "account_id"
      t.datetime "end_at"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.integer "alerted_id"
      t.string "alerted_type"
      t.string "query_key", default: "", null: false
      t.text "options"
      t.string "resolution"
    end

    add_index "alerts", ["account_id"], name: "index_alerts_on_account_id"
    add_index "alerts", ["alerted_id", "alerted_type"], name: "index_alerts_on_alerted_id_and_alerted_type"
    add_index "alerts", ["query_key"], name: "index_alerts_on_key"

    create_table "audio_file_deliveries", force: true do |t|
      t.string "status"
      t.integer "job_id"
      t.integer "audio_file_id"
      t.integer "delivery_id"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string "cart_number"
      t.string "destination"
      t.integer "segment_number"
    end

    add_index "audio_file_deliveries", ["delivery_id"], name: "index_audio_file_deliveries_on_delivery_id"

    create_table "audio_file_listenings", force: true do |t|
      t.integer "audio_file_id", default: 0, null: false
      t.boolean "thirty_seconds", default: false
      t.integer "user_id"
      t.string "cookie"
      t.string "user_agent"
      t.string "ip_address"
      t.string "from_page"
      t.datetime "created_at"
      t.datetime "updated_at"
    end

    add_index "audio_file_listenings", ["audio_file_id"], name: "audio_file_id_idx"

    create_table "audio_file_templates", force: true do |t|
      t.integer "audio_version_template_id"
      t.integer "position"
      t.string "label"
      t.integer "length_minimum"
      t.integer "length_maximum"
      t.datetime "created_at"
      t.datetime "updated_at"
    end

    create_table "audio_files", force: true do |t|
      t.integer "position"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.integer "audio_version_id"
      t.integer "account_id"
      t.integer "size"
      t.string "content_type"
      t.string "filename"
      t.integer "parent_id"
      t.string "label"
      t.integer "length"
      t.integer "layer"
      t.integer "bit_rate", default: 0, null: false
      t.decimal "frequency", precision: 5, scale: 2, default: 0.0, null: false
      t.string "channel_mode"
      t.string "status"
      t.string "format"
      t.datetime "deleted_at"
      t.string "listenable_type"
      t.integer "listenable_id"
      t.text "upload_path"
      t.integer "current_job_id"
      t.text "status_message"
      t.decimal "integrated_loudness", precision: 15, scale: 10
      t.decimal "loudness_range", precision: 15, scale: 10
      t.decimal "true_peak", precision: 15, scale: 10
    end

    add_index "audio_files", ["account_id", "filename"], name: "index_audio_files_on_account_id_and_filename"
    add_index "audio_files", ["account_id"], name: "audio_files_account_id_fk"
    add_index "audio_files", ["audio_version_id"], name: "audio_files_audio_version_id_fk"
    add_index "audio_files", ["listenable_type", "listenable_id"], name: "listenable_idx"
    add_index "audio_files", ["parent_id"], name: "audio_files_parent_id_fk"
    add_index "audio_files", ["position"], name: "position_idx"
    add_index "audio_files", ["status"], name: "status_idx"

    create_table "audio_version_templates", force: true do |t|
      t.integer "series_id"
      t.string "label"
      t.boolean "promos"
      t.integer "length_minimum"
      t.integer "segment_count"
      t.integer "length_maximum"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string "content_type"
    end

    create_table "audio_versions", force: true do |t|
      t.integer "piece_id"
      t.string "label"
      t.text "content_advisory"
      t.text "timing_and_cues"
      t.text "transcript", limit: 16777215
      t.boolean "news_hole_break"
      t.boolean "floating_break"
      t.boolean "bottom_of_hour_break"
      t.boolean "twenty_forty_break"
      t.boolean "promos", default: false, null: false
      t.datetime "deleted_at"
      t.integer "audio_version_template_id"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string "explicit"
      t.string "status"
      t.text "status_message"
    end

    add_index "audio_versions", ["piece_id"], name: "audio_versions_piece_id_fk"
    add_index "audio_versions", ["updated_at"], name: "index_audio_versions_on_updated_at"

    create_table "available_for_tasks", force: true do |t|
      t.string "name"
      t.integer "user_id"
    end

    add_index "available_for_tasks", ["user_id"], name: "available_for_tasks_user_id_fk"

    create_table "awards", force: true do |t|
      t.integer "awardable_id"
      t.string "awardable_type"
      t.string "name"
      t.string "description"
      t.date "awarded_on"
    end

    create_table "badges_privileges", force: true do |t|
      t.string "name"
      t.datetime "created_at"
      t.datetime "updated_at"
    end

    add_index "badges_privileges", ["name"], name: "index_badges_privileges_on_name", unique: true
    add_index "badges_privileges", ["name"], name: "name_idx"

    create_table "badges_role_privileges", force: true do |t|
      t.integer "role_id"
      t.integer "privilege_id"
      t.datetime "created_at"
      t.datetime "updated_at"
    end

    add_index "badges_role_privileges", ["role_id", "privilege_id"], name: "index_badges_role_privileges_on_role_id_and_privilege_id"

    create_table "badges_roles", force: true do |t|
      t.string "name", limit: 50
      t.datetime "created_at"
      t.datetime "updated_at"
    end

    add_index "badges_roles", ["name"], name: "index_badges_roles_on_name", unique: true

    create_table "badges_user_roles", force: true do |t|
      t.integer "user_id"
      t.integer "role_id"
      t.integer "authorizable_id"
      t.string "authorizable_type"
      t.datetime "created_at"
      t.datetime "updated_at"
    end

    add_index "badges_user_roles", ["authorizable_type", "authorizable_id"], name: "authorizable_idx"
    add_index "badges_user_roles", ["user_id", "role_id", "authorizable_type", "authorizable_id"], name: "user_role_authorize"
    add_index "badges_user_roles", ["user_id"], name: "index_badges_user_roles_on_user_id"

    create_table "blacklists", force: true do |t|
      t.string "domain"
      t.datetime "created_at"
      t.datetime "updated_at"
    end

    add_index "blacklists", ["domain"], name: "index_blacklists_on_domain", unique: true

    create_table "carriages", force: true do |t|
      t.integer "purchase_id"
      t.text "comments"
      t.datetime "aired_at"
      t.string "air_time"
      t.string "medium"
      t.datetime "created_at"
      t.datetime "updated_at"
    end

    add_index "carriages", ["purchase_id"], name: "purchase_id_idx"

    create_table "cart_number_sequences", force: true do |t|
      t.integer "numbered_id"
      t.string "numbered_type"
      t.integer "start_number"
      t.integer "end_number"
      t.datetime "created_at"
      t.datetime "updated_at"
    end

    create_table "client_applications", force: true do |t|
      t.string "name"
      t.string "url"
      t.string "support_url"
      t.string "callback_url"
      t.string "key", limit: 40
      t.string "secret", limit: 40
      t.integer "user_id"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string "image_url"
      t.string "description"
      t.string "template_name"
      t.boolean "auto_grant", default: false
    end

    add_index "client_applications", ["key"], name: "index_client_applications_on_key", unique: true
    add_index "client_applications", ["name"], name: "client_applications_unique_name_idx", unique: true

    create_table "cms_say_when_job_executions", force: true do |t|
      t.integer "job_id"
      t.string "status"
      t.text "result"
      t.datetime "start_at"
      t.datetime "end_at"
    end

    add_index "cms_say_when_job_executions", ["job_id"], name: "index_cms_say_when_job_executions_on_job_id"

    create_table "cms_say_when_jobs", force: true do |t|
      t.string "group"
      t.string "name"
      t.string "status"
      t.string "trigger_strategy"
      t.text "trigger_options"
      t.datetime "last_fire_at"
      t.datetime "next_fire_at"
      t.datetime "start_at"
      t.datetime "end_at"
      t.string "job_class"
      t.string "job_method"
      t.text "data"
      t.string "scheduled_type"
      t.integer "scheduled_id"
      t.datetime "created_at"
      t.datetime "updated_at"
    end

    add_index "cms_say_when_jobs", ["next_fire_at", "status"], name: "index_cms_say_when_jobs_on_next_fire_at_and_status"
    add_index "cms_say_when_jobs", ["scheduled_type", "scheduled_id"], name: "index_cms_say_when_jobs_on_scheduled_type_and_scheduled_id"

    create_table "comatose_files", force: true do |t|
      t.integer "parent_id"
      t.string "content_type"
      t.string "filename"
      t.string "thumbnail"
      t.integer "size"
      t.integer "width"
      t.integer "height"
      t.float "aspect_ratio"
    end

    create_table "comatose_page_files", force: true do |t|
      t.integer "page_id"
      t.integer "file_attachment_id"
    end

    create_table "comatose_page_versions", force: true do |t|
      t.integer "comatose_page_id"
      t.integer "version"
      t.integer "parent_id", limit: 8
      t.text "full_path"
      t.string "title"
      t.string "slug"
      t.string "keywords"
      t.text "body", limit: 16777215
      t.string "filter_type", limit: 25, default: "Textile"
      t.string "author"
      t.integer "position", limit: 8, default: 0
      t.datetime "updated_on"
      t.datetime "created_on"
      t.string "status", limit: 20
      t.datetime "published_on"
    end

    add_index "comatose_page_versions", ["comatose_page_id", "version"], name: "comatose_page_id_version_idx"
    add_index "comatose_page_versions", ["comatose_page_id"], name: "comatose_page_id_idx"
    add_index "comatose_page_versions", ["version"], name: "version_idx"

    create_table "comatose_pages", force: true do |t|
      t.integer "parent_id"
      t.text "full_path"
      t.string "title"
      t.string "slug"
      t.string "keywords"
      t.text "body", limit: 16777215
      t.string "filter_type", limit: 25, default: "Textile"
      t.string "author"
      t.integer "position", default: 0
      t.integer "version"
      t.datetime "updated_on"
      t.datetime "created_on"
      t.string "status", limit: 40, default: "draft"
      t.datetime "published_on"
    end

    create_table "comment_ratings", force: true do |t|
      t.integer "comment_id"
      t.integer "user_id"
      t.boolean "helpful", default: false
      t.datetime "created_at"
      t.datetime "updated_at"
    end

    create_table "comments", force: true do |t|
      t.string "commentable_type"
      t.integer "commentable_id"
      t.string "title"
      t.text "body"
      t.integer "user_id"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.datetime "deleted_at"
    end

    add_index "comments", ["commentable_type", "commentable_id"], name: "index_comments_on_commentable_type_and_commentable_id"
    add_index "comments", ["deleted_at"], name: "deleted_at_idx"
    add_index "comments", ["user_id"], name: "user_id_idx"

    create_table "contact_associations", force: true do |t|
      t.integer "user_id"
      t.integer "contact_id"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.datetime "confirmed_at"
    end

    create_table "date_peg_instances", force: true do |t|
      t.integer "date_peg_id"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.date "start_date"
      t.date "end_date"
    end

    create_table "date_pegs", force: true do |t|
      t.string "name"
      t.string "description"
      t.integer "playlist_id"
      t.string "slug"
    end

    create_table "default_images", force: true do |t|
      t.integer "parent_id"
      t.integer "position"
      t.string "filename"
      t.string "content_type"
      t.integer "size"
      t.integer "width"
      t.integer "height"
      t.float "aspect_ratio"
      t.string "thumbnail"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string "caption"
      t.string "credit"
      t.string "tone"
      t.string "credit_url"
    end

    create_table "delegations", force: true do |t|
      t.integer "account_id"
      t.integer "delegate_account_id"
      t.string "role"
      t.datetime "created_at"
      t.datetime "updated_at"
    end

    add_index "delegations", ["account_id", "delegate_account_id", "role"], name: "index_delegations_on_account_id_and_delegate_account_id_and_role", unique: true
    add_index "delegations", ["delegate_account_id"], name: "index_delegations_on_delegate_account_id"

    create_table "deliveries", force: true do |t|
      t.integer "subscription_id"
      t.integer "piece_id"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.integer "purchase_id"
      t.string "status"
      t.string "transport_method"
      t.string "filename_format"
      t.string "audio_type"
      t.integer "cart_number_start"
      t.integer "end_air_days"
      t.integer "audio_version_id"
      t.boolean "deliver_promos"
      t.integer "episode_number"
    end

    add_index "deliveries", ["subscription_id", "episode_number"], name: "index_deliveries_on_subscription_id_and_episode_number"

    create_table "delivery_logs", force: true do |t|
      t.integer "delivery_id"
      t.string "status"
      t.string "message"
      t.text "result"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.integer "audio_file_delivery_id"
      t.datetime "logged_at", limit: 3
      t.string "porter_execution_id"
      t.string "porter_job_id"
      t.string "porter_state"
    end

    add_index "delivery_logs", ["audio_file_delivery_id", "logged_at", "status"], name: "delivery_logs_audio_logged_status_index"
    add_index "delivery_logs", ["delivery_id", "audio_file_delivery_id", "logged_at"], name: "delivery_delivery_logs"

    create_table "discounts", force: true do |t|
      t.integer "discountable_id"
      t.string "discountable_type"
      t.float "amount"
      t.string "type"
      t.text "note"
      t.date "expires_at"
      t.date "starts_at"
    end

    create_table "distribution_templates", force: true do |t|
      t.integer "distribution_id"
      t.integer "audio_version_template_id"
      t.datetime "created_at"
      t.datetime "updated_at"
    end

    add_index "distribution_templates", ["distribution_id", "audio_version_template_id"], name: "index_distribution_templates", unique: true

    create_table "distributions", force: true do |t|
      t.string "type"
      t.string "distributable_type"
      t.integer "distributable_id"
      t.string "url"
      t.string "guid"
      t.text "properties"
      t.datetime "created_at"
      t.datetime "updated_at"
    end

    add_index "distributions", ["distributable_type", "distributable_id"], name: "index_distributions_on_distributable_type_and_distributable_id"

    create_table "educational_experiences", force: true do |t|
      t.string "degree"
      t.string "school"
      t.integer "user_id"
      t.date "graduated_on"
    end

    add_index "educational_experiences", ["user_id"], name: "educational_experiences_user_id_fk"

    create_table "episode_imports", force: true do |t|
      t.integer "podcast_import_id"
      t.integer "piece_id"
      t.string "guid"
      t.text "entry"
      t.text "audio"
      t.string "status"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.boolean "has_duplicate_guid", default: false
    end

    add_index "episode_imports", ["has_duplicate_guid"], name: "index_episode_imports_on_has_duplicate_guid"
    add_index "episode_imports", ["podcast_import_id"], name: "index_episode_imports_on_podcast_import_id"

    create_table "equipment", force: true do |t|
      t.string "name"
      t.integer "user_id"
    end

    add_index "equipment", ["user_id"], name: "equipment_user_id_fk"

    create_table "financial_transactions", force: true do |t|
      t.string "paypal_transaction_id"
      t.string "paypal_type"
      t.string "status"
      t.datetime "received_at"
      t.string "gross"
      t.string "fee"
      t.string "currency"
      t.integer "account_membership_id"
      t.string "account"
      t.string "invoice"
      t.datetime "created_at"
      t.datetime "updated_at"
    end

    create_table "flags", force: true do |t|
      t.integer "user_id"
      t.integer "flaggable_id"
      t.string "flaggable_type"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string "reason"
    end

    add_index "flags", ["flaggable_id", "flaggable_type"], name: "flaggable_idx"

    create_table "formats", force: true do |t|
      t.integer "piece_id"
      t.string "name"
    end

    add_index "formats", ["name"], name: "name_idx"
    add_index "formats", ["piece_id"], name: "formats_piece_id_fk"

    create_table "ftp_addresses", force: true do |t|
      t.integer "ftpable_id"
      t.string "ftpable_type"
      t.string "host"
      t.string "port"
      t.string "user"
      t.string "password"
      t.string "directory"
      t.text "options"
      t.string "protocol", default: "ftp"
    end

    create_table "geo_data", force: true do |t|
      t.string "zip_code"
      t.string "zip_type"
      t.string "city"
      t.string "city_type"
      t.string "county"
      t.string "county_fips"
      t.string "state"
      t.string "state_abbr"
      t.string "state_fips"
      t.string "msa_code"
      t.string "area_code"
      t.string "time_zone"
      t.string "utc"
      t.string "dst"
      t.float "latitude"
      t.float "longitude"
    end

    add_index "geo_data", ["area_code"], name: "area_code_idx"
    add_index "geo_data", ["latitude"], name: "latitude_idx"
    add_index "geo_data", ["longitude"], name: "longitude_idx"
    add_index "geo_data", ["time_zone"], name: "time_zone_idx"
    add_index "geo_data", ["zip_code"], name: "zip_code_idx"

    create_table "geocodes", force: true do |t|
      t.decimal "latitude", precision: 15, scale: 12
      t.decimal "longitude", precision: 15, scale: 12
      t.string "query"
      t.string "street"
      t.string "locality"
      t.string "region"
      t.string "postal_code"
      t.string "country"
      t.boolean "approximate"
    end

    add_index "geocodes", ["latitude"], name: "geocodes_latitude_index"
    add_index "geocodes", ["longitude"], name: "geocodes_longitude_index"
    add_index "geocodes", ["query"], name: "geocodes_query_index", unique: true

    create_table "geocodings", force: true do |t|
      t.integer "geocodable_id"
      t.integer "geocode_id"
      t.string "geocodable_type"
    end

    add_index "geocodings", ["geocodable_id"], name: "geocodings_geocodable_id_index"
    add_index "geocodings", ["geocodable_type"], name: "geocodings_geocodable_type_index"
    add_index "geocodings", ["geocode_id"], name: "geocodings_geocode_id_index"

    create_table "greylistings", force: true do |t|
      t.integer "piece_id"
      t.datetime "created_at"
      t.datetime "updated_at"
    end

    add_index "greylistings", ["piece_id"], name: "piece_id_idx"

    create_table "identities", force: true do |t|
      t.integer "user_id"
      t.string "provider"
      t.string "accesstoken"
      t.string "uid"
      t.string "email"
      t.text "image_url"
      t.string "secrettoken"
      t.string "refreshtoken"
      t.datetime "created_at"
      t.datetime "updated_at"
    end

    add_index "identities", ["user_id"], name: "index_identities_on_user_id"

    create_table "languages", force: true do |t|
      t.string "name"
      t.integer "user_id"
    end

    add_index "languages", ["user_id"], name: "languages_user_id_fk"

    create_table "license_versions", force: true do |t|
      t.integer "license_id"
      t.integer "version"
      t.integer "piece_id", limit: 8
      t.string "website_usage"
      t.string "allow_edit"
      t.text "additional_terms"
      t.integer "version_user_id", limit: 8
      t.datetime "updated_at"
      t.datetime "deleted_at"
      t.datetime "created_at"
    end

    add_index "license_versions", ["license_id", "version"], name: "index_license_versions_on_license_id_and_version", unique: true

    create_table "licenses", force: true do |t|
      t.integer "piece_id"
      t.string "website_usage"
      t.string "allow_edit"
      t.text "additional_terms"
      t.integer "version_user_id"
      t.integer "version"
      t.datetime "deleted_at"
      t.datetime "created_at"
      t.datetime "updated_at"
    end

    add_index "licenses", ["piece_id"], name: "licenses_piece_id_fk"
    add_index "licenses", ["updated_at"], name: "index_licenses_on_updated_at"

    create_table "memberships", force: true do |t|
      t.integer "account_id"
      t.integer "user_id"
      t.text "request"
      t.boolean "approved"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string "role"
    end

    add_index "memberships", ["account_id", "user_id"], name: "uniq_user_account", unique: true
    add_index "memberships", ["account_id"], name: "memberships_account_id_fk"
    add_index "memberships", ["updated_at"], name: "index_memberships_on_updated_at"
    add_index "memberships", ["user_id"], name: "memberships_user_id_fk"

    create_table "memberships_archive", force: true do |t|
      t.integer "account_id"
      t.integer "user_id"
      t.text "request"
      t.boolean "approved"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string "role"
    end

    add_index "memberships_archive", ["account_id"], name: "memberships_account_id_fk"
    add_index "memberships_archive", ["updated_at"], name: "index_memberships_on_updated_at"
    add_index "memberships_archive", ["user_id"], name: "memberships_user_id_fk"

    create_table "message_receptions", force: true do |t|
      t.integer "message_id"
      t.integer "recipient_id"
      t.boolean "read", default: false
      t.datetime "created_at"
      t.datetime "updated_at"
      t.boolean "deleted_by_recipient", default: false
    end

    add_index "message_receptions", ["message_id"], name: "index_message_receptions_on_message_id"
    add_index "message_receptions", ["recipient_id", "deleted_by_recipient"], name: "by_recipient"
    add_index "message_receptions", ["recipient_id", "message_id", "deleted_by_recipient"], name: "message_receptions_inbox_index"

    create_table "message_recipient_finders", force: true do |t|
      t.text "finder_expression"
      t.string "label"
      t.datetime "created_at"
      t.datetime "updated_at"
    end

    create_table "messages", force: true do |t|
      t.integer "sender_id"
      t.string "subject"
      t.text "body"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.integer "parent_id"
      t.boolean "deleted_by_sender", default: false
      t.string "type"
      t.integer "priority"
      t.integer "message_recipient_finder_id"
    end

    add_index "messages", ["parent_id"], name: "index_messages_on_parent_id"
    add_index "messages", ["sender_id", "deleted_by_sender"], name: "index_messages_on_sender_id_and_deleted_by_sender"

    create_table "musical_works", force: true do |t|
      t.integer "position"
      t.integer "piece_id"
      t.string "title"
      t.string "artist"
      t.string "album"
      t.string "label"
      t.integer "year"
      t.integer "excerpt_length"
      t.datetime "created_at"
      t.datetime "updated_at"
    end

    add_index "musical_works", ["piece_id"], name: "musical_works_piece_id_fk"
    add_index "musical_works", ["updated_at"], name: "index_musical_works_on_updated_at"

    create_table "network_files", force: true do |t|
      t.datetime "created_at"
      t.datetime "updated_at"
    end

    create_table "network_memberships", force: true do |t|
      t.integer "account_id"
      t.integer "network_id"
      t.datetime "created_at"
      t.datetime "updated_at"
    end

    create_table "network_pieces", force: true do |t|
      t.integer "piece_id"
      t.integer "network_id"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.integer "point_level"
      t.integer "custom_points"
      t.datetime "has_custom_points_at"
    end

    add_index "network_pieces", ["network_id"], name: "network_pieces_network_id_fk"
    add_index "network_pieces", ["piece_id"], name: "network_pieces_piece_id_fk"

    create_table "network_requests", force: true do |t|
      t.integer "account_id"
      t.integer "user_id"
      t.string "name"
      t.string "description"
      t.string "pricing_strategy", default: "", null: false
      t.string "publishing_strategy", default: "", null: false
      t.string "notification_strategy", default: "", null: false
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string "state", default: "pending"
      t.text "note"
      t.datetime "reviewed_at"
      t.string "path"
    end

    create_table "networks", force: true do |t|
      t.integer "account_id"
      t.string "name"
      t.string "description"
      t.string "pricing_strategy"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string "publishing_strategy", default: "", null: false
      t.string "notification_strategy", default: "", null: false
      t.string "path"
    end

    create_table "numeric_sequences", force: true do |t|
      t.string "name"
      t.integer "last_number"
      t.datetime "created_at"
      t.datetime "updated_at"
    end

    add_index "numeric_sequences", ["name"], name: "index_numeric_sequences_on_name", unique: true

    create_table "oauth_access_grants", force: true do |t|
      t.integer "resource_owner_id", null: false
      t.integer "application_id", null: false
      t.string "token", null: false
      t.integer "expires_in", null: false
      t.text "redirect_uri", null: false
      t.datetime "created_at", null: false
      t.datetime "revoked_at"
      t.string "scopes"
    end

    add_index "oauth_access_grants", ["token"], name: "index_oauth_access_grants_on_token", unique: true

    create_table "oauth_access_tokens", force: true do |t|
      t.integer "resource_owner_id"
      t.integer "application_id"
      t.string "token", null: false
      t.string "refresh_token"
      t.integer "expires_in"
      t.datetime "revoked_at"
      t.datetime "created_at", null: false
      t.string "scopes"
      t.string "previous_refresh_token", default: "", null: false
    end

    add_index "oauth_access_tokens", ["refresh_token"], name: "index_oauth_access_tokens_on_refresh_token", unique: true
    add_index "oauth_access_tokens", ["resource_owner_id"], name: "index_oauth_access_tokens_on_resource_owner_id"
    add_index "oauth_access_tokens", ["token"], name: "index_oauth_access_tokens_on_token", unique: true

    create_table "oauth_applications", force: true do |t|
      t.string "name", null: false
      t.string "uid", null: false
      t.string "secret", null: false
      t.text "redirect_uri", null: false
      t.string "scopes", default: "", null: false
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
    end

    add_index "oauth_applications", ["uid"], name: "index_oauth_applications_on_uid", unique: true

    create_table "oauth_nonces", force: true do |t|
      t.string "nonce"
      t.integer "timestamp"
      t.datetime "created_at"
      t.datetime "updated_at"
    end

    add_index "oauth_nonces", ["nonce", "timestamp"], name: "index_oauth_nonces_on_nonce_and_timestamp", unique: true

    create_table "oauth_tokens", force: true do |t|
      t.integer "user_id"
      t.string "type", limit: 20
      t.integer "client_application_id"
      t.string "token", limit: 40
      t.string "secret", limit: 40
      t.string "callback_url"
      t.string "verifier", limit: 20
      t.string "scope"
      t.datetime "authorized_at"
      t.datetime "invalidated_at"
      t.datetime "expires_at"
      t.datetime "created_at"
      t.datetime "updated_at"
    end

    add_index "oauth_tokens", ["token"], name: "index_oauth_tokens_on_token", unique: true

    create_table "open_id_associations", force: true do |t|
      t.binary "server_url", null: false
      t.string "handle", null: false
      t.binary "secret", null: false
      t.integer "issued", null: false
      t.integer "lifetime", null: false
      t.string "assoc_type", null: false
    end

    create_table "open_id_nonces", force: true do |t|
      t.string "server_url", null: false
      t.integer "timestamp", null: false
      t.string "salt", null: false
    end

    create_table "outside_purchaser_info_versions", force: true do |t|
      t.integer "outside_purchaser_info_id"
      t.integer "version"
      t.integer "outside_purchaser_id", limit: 8
      t.string "payment_type"
      t.string "purchaser_type"
      t.decimal "rate", precision: 9, scale: 2
      t.text "terms"
      t.text "description"
      t.text "payment_terms"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.integer "version_user_id", limit: 8
      t.datetime "deleted_at"
    end

    create_table "outside_purchaser_infos", force: true do |t|
      t.integer "outside_purchaser_id"
      t.string "payment_type"
      t.string "purchaser_type"
      t.decimal "rate", precision: 9, scale: 2
      t.text "terms"
      t.text "description"
      t.text "payment_terms"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.integer "version_user_id"
      t.integer "version"
      t.datetime "deleted_at"
    end

    add_index "outside_purchaser_infos", ["outside_purchaser_id"], name: "outside_purchaser_infos_outside_purchaser_id_fk"

    create_table "outside_purchaser_optins", force: true do |t|
      t.integer "piece_id"
      t.integer "outside_purchaser_id"
      t.datetime "created_at"
      t.datetime "updated_at"
    end

    add_index "outside_purchaser_optins", ["outside_purchaser_id"], name: "outside_purchaser_pieces_outside_purchaser_id_fk"
    add_index "outside_purchaser_optins", ["piece_id"], name: "outside_purchaser_pieces_piece_id_fk"

    create_table "outside_purchaser_preferences", force: true do |t|
      t.integer "account_id"
      t.integer "outside_purchaser_id"
      t.string "allow"
      t.datetime "created_at"
      t.datetime "updated_at"
    end

    add_index "outside_purchaser_preferences", ["account_id"], name: "account_outside_purchaser_options_account_id_fk"
    add_index "outside_purchaser_preferences", ["outside_purchaser_id"], name: "account_outside_purchaser_options_outside_purchaser_id_fk"

    create_table "piece_date_pegs", force: true do |t|
      t.integer "piece_id"
      t.integer "date_peg_id"
      t.string "name"
      t.integer "year"
      t.integer "month"
      t.integer "day"
    end

    add_index "piece_date_pegs", ["date_peg_id"], name: "piece_date_pegs_date_peg_id_fk"
    add_index "piece_date_pegs", ["piece_id"], name: "piece_date_pegs_piece_id_fk"

    create_table "piece_files", force: true do |t|
      t.datetime "created_at"
      t.datetime "updated_at"
      t.integer "piece_id"
      t.integer "size"
      t.string "content_type"
      t.string "filename"
      t.string "label"
    end

    add_index "piece_files", ["piece_id"], name: "piece_files_piece_id_fk"

    create_table "piece_images", force: true do |t|
      t.integer "parent_id"
      t.string "content_type"
      t.string "filename"
      t.string "thumbnail"
      t.integer "size"
      t.integer "width"
      t.integer "height"
      t.float "aspect_ratio"
      t.integer "piece_id"
      t.string "caption"
      t.string "credit"
      t.integer "position"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.text "upload_path"
      t.string "status"
      t.string "purpose"
    end

    add_index "piece_images", ["parent_id"], name: "parent_id_idx"
    add_index "piece_images", ["piece_id"], name: "piece_images_piece_id_fk"
    add_index "piece_images", ["position"], name: "position_idx"

    create_table "pieces", force: true do |t|
      t.integer "position"
      t.integer "account_id"
      t.integer "creator_id"
      t.integer "series_id"
      t.string "title"
      t.text "short_description", limit: 16777215
      t.text "description", limit: 16777215
      t.date "produced_on"
      t.string "language"
      t.string "related_website"
      t.text "credits", limit: 16777215
      t.text "broadcast_history", limit: 16777215
      t.text "intro", limit: 16777215
      t.text "outro", limit: 16777215
      t.datetime "created_at"
      t.datetime "updated_at"
      t.integer "length"
      t.integer "point_level"
      t.datetime "published_at"
      t.datetime "deleted_at"
      t.text "legacy_musical_works", limit: 16777215
      t.integer "episode_number"
      t.datetime "network_only_at"
      t.integer "image_id"
      t.datetime "featured_at"
      t.boolean "allow_comments", default: true
      t.float "average_rating"
      t.integer "npr_story_id"
      t.datetime "is_exportable_at"
      t.integer "custom_points"
      t.datetime "is_shareable_at"
      t.datetime "has_custom_points_at"
      t.boolean "publish_on_valid"
      t.datetime "publish_notified_at"
      t.datetime "publish_on_valid_at"
      t.datetime "promos_only_at"
      t.string "episode_identifier"
      t.string "app_version", default: "v3", null: false
      t.string "marketplace_subtitle"
      t.text "marketplace_information", limit: 16777215
      t.integer "network_id"
      t.datetime "released_at"
      t.string "status"
      t.text "status_message", limit: 16777215
      t.string "season_identifier"
      t.string "clean_title"
      t.string "production_notes"
    end

    add_index "pieces", ["account_id"], name: "pieces_account_id_fk"
    add_index "pieces", ["created_at", "published_at"], name: "created_published_index"
    add_index "pieces", ["creator_id"], name: "pieces_creator_id_fk"
    add_index "pieces", ["deleted_at", "published_at", "network_only_at"], name: "public_pieces_index"
    add_index "pieces", ["deleted_at"], name: "deleted_at_idx"
    add_index "pieces", ["episode_number", "series_id"], name: "index_pieces_on_episode_number_and_series_id"
    add_index "pieces", ["network_id", "network_only_at", "deleted_at"], name: "index_pieces_on_network_id_and_network_only_at_and_deleted_at"
    add_index "pieces", ["published_at"], name: "by_published_at"
    add_index "pieces", ["series_id", "deleted_at"], name: "series_episodes"
    add_index "pieces", ["series_id"], name: "pieces_series_id_fk"

    create_table "playlist_images", force: true do |t|
      t.integer "parent_id"
      t.string "content_type"
      t.string "filename"
      t.string "thumbnail"
      t.integer "size"
      t.integer "width"
      t.integer "height"
      t.float "aspect_ratio"
      t.integer "playlist_id"
      t.string "caption"
      t.string "credit"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.text "upload_path"
      t.string "status"
    end

    create_table "playlist_sections", force: true do |t|
      t.integer "playlist_id"
      t.string "title"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.integer "position"
      t.text "comment"
    end

    add_index "playlist_sections", ["playlist_id"], name: "playlist_idx"
    add_index "playlist_sections", ["position"], name: "position_idx"

    create_table "playlisting_images", force: true do |t|
      t.integer "parent_id"
      t.string "content_type"
      t.string "filename"
      t.string "thumbnail"
      t.integer "size"
      t.integer "width"
      t.integer "height"
      t.float "aspect_ratio"
      t.integer "playlisting_id"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string "caption"
      t.string "credit"
      t.text "upload_path"
      t.string "status"
    end

    add_index "playlisting_images", ["playlisting_id"], name: "playlisting_images_playlisting_id_fk"

    create_table "playlistings", force: true do |t|
      t.integer "playlist_section_id"
      t.integer "playlistable_id"
      t.string "playlistable_type"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.integer "position"
      t.text "comment"
      t.string "editors_title"
    end

    add_index "playlistings", ["playlist_section_id"], name: "playlist_section_id_idx"
    add_index "playlistings", ["playlistable_id", "playlistable_type"], name: "playlistable_idx"

    create_table "playlists", force: true do |t|
      t.string "title"
      t.integer "account_id"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.text "description"
      t.integer "position"
      t.datetime "curated_at"
      t.datetime "featured_at"
      t.string "type"
      t.datetime "deleted_at"
      t.datetime "published_at"
      t.datetime "allow_free_purchase_at"
      t.string "path"
    end

    add_index "playlists", ["account_id"], name: "account_idx"
    add_index "playlists", ["deleted_at"], name: "deleted_at_idx"
    add_index "playlists", ["published_at"], name: "published_at_idx"
    add_index "playlists", ["type"], name: "type_idx"

    create_table "podcast_imports", force: true do |t|
      t.integer "user_id"
      t.integer "account_id"
      t.integer "series_id"
      t.string "url"
      t.string "status"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.text "config", limit: 2147483647
      t.integer "feed_episode_count"
    end

    create_table "point_package_versions", force: true do |t|
      t.integer "point_package_id"
      t.integer "version"
      t.integer "account_id", limit: 8
      t.integer "seller_id", limit: 8
      t.integer "points", limit: 8
      t.date "expires_on"
      t.integer "total_station_revenue", limit: 8
      t.decimal "price", precision: 9, scale: 2
      t.decimal "list", precision: 9, scale: 2
      t.decimal "discount", precision: 9, scale: 2
      t.datetime "created_at"
      t.datetime "updated_at"
      t.text "notes"
      t.datetime "deleted_at"
      t.decimal "prx_cut", precision: 9, scale: 2
      t.decimal "royalty_cut", precision: 9, scale: 2
      t.string "package_type"
      t.date "ends_on"
      t.integer "prx_percentage", limit: 8
      t.integer "subscription_id", limit: 8
      t.integer "points_purchased", limit: 8
      t.integer "version_user_id", limit: 8
      t.decimal "witholding", precision: 9, scale: 2
      t.boolean "locked"
    end

    create_table "point_packages", force: true do |t|
      t.integer "account_id"
      t.integer "seller_id"
      t.integer "points"
      t.date "expires_on"
      t.integer "total_station_revenue"
      t.decimal "price", precision: 9, scale: 2
      t.decimal "list", precision: 9, scale: 2
      t.decimal "discount", precision: 9, scale: 2
      t.datetime "created_at"
      t.datetime "updated_at"
      t.text "notes"
      t.datetime "deleted_at"
      t.decimal "prx_cut", precision: 9, scale: 2
      t.decimal "royalty_cut", precision: 9, scale: 2
      t.string "package_type"
      t.date "ends_on"
      t.integer "prx_percentage"
      t.integer "subscription_id"
      t.integer "points_purchased"
      t.integer "version_user_id"
      t.integer "version"
      t.decimal "witholding", precision: 9, scale: 2
      t.boolean "locked", default: true
    end

    add_index "point_packages", ["account_id"], name: "point_packages_account_id_fk"
    add_index "point_packages", ["seller_id"], name: "point_packages_seller_id_fk"

    create_table "pricing_tiers", force: true do |t|
      t.integer "minimum_tsr"
      t.integer "maximum_tsr"
      t.datetime "created_at"
      t.datetime "updated_at"
    end

    create_table "pricing_tiers_seasons", id: false, force: true do |t|
      t.integer "pricing_tier_id"
      t.integer "season_id"
    end

    create_table "privacy_settings", force: true do |t|
      t.integer "protect_id"
      t.string "protect_type"
      t.string "level"
      t.string "information"
      t.datetime "created_at"
      t.datetime "updated_at"
    end

    add_index "privacy_settings", ["information"], name: "information_idx"
    add_index "privacy_settings", ["protect_id", "protect_type"], name: "protect_idx"

    create_table "producers", force: true do |t|
      t.integer "piece_id"
      t.integer "user_id"
      t.string "name"
      t.datetime "invited_at"
      t.string "email"
      t.datetime "deleted_at"
      t.datetime "created_at"
      t.datetime "updated_at"
    end

    add_index "producers", ["piece_id"], name: "producers_piece_id_fk"
    add_index "producers", ["updated_at"], name: "index_producers_on_updated_at"
    add_index "producers", ["user_id"], name: "producers_user_id_fk"

    create_table "purchase_allocations", force: true do |t|
      t.integer "purchase_id"
      t.integer "point_package_id"
      t.decimal "quantity", precision: 9, scale: 2
      t.datetime "created_at"
      t.datetime "updated_at"
    end

    create_table "purchases", force: true do |t|
      t.integer "seller_account_id"
      t.integer "purchaser_account_id"
      t.integer "purchaser_id"
      t.integer "purchased_id"
      t.integer "license_version"
      t.datetime "purchased_at"
      t.date "expires_on"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.decimal "price", precision: 9, scale: 2
      t.string "unit"
      t.string "payment_type"
      t.decimal "royalty_base", precision: 9, scale: 2
      t.decimal "royalty_bonus", precision: 9, scale: 2
      t.decimal "royalty_subsidy", precision: 9, scale: 2
      t.string "purchased_type"
      t.integer "network_id"
    end

    add_index "purchases", ["purchased_at"], name: "purchased_at_idx"
    add_index "purchases", ["purchased_id", "purchased_type"], name: "purchased_idx"
    add_index "purchases", ["purchaser_account_id"], name: "purchases_purchaser_account_id_fk"
    add_index "purchases", ["purchaser_id"], name: "purchases_purchaser_id_fk"
    add_index "purchases", ["seller_account_id"], name: "purchases_seller_account_id_fk"

    create_table "ratings", force: true do |t|
      t.integer "user_id"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.integer "value", default: 0, null: false
      t.integer "ratable_id", default: 0, null: false
      t.string "ratable_type", default: "", null: false
    end

    add_index "ratings", ["ratable_type", "ratable_id"], name: "index_ratings_on_ratable_type_and_ratable_id"

    create_table "say_when_job_executions", force: true do |t|
      t.integer "job_id"
      t.string "status"
      t.text "result"
      t.datetime "start_at"
      t.datetime "end_at"
    end

    add_index "say_when_job_executions", ["job_id"], name: "index_say_when_job_executions_on_job_id"

    create_table "say_when_jobs", force: true do |t|
      t.string "group"
      t.string "name"
      t.string "status"
      t.string "trigger_strategy"
      t.text "trigger_options"
      t.datetime "last_fire_at"
      t.datetime "next_fire_at"
      t.datetime "start_at"
      t.datetime "end_at"
      t.string "job_class"
      t.string "job_method"
      t.text "data"
      t.string "scheduled_type"
      t.integer "scheduled_id"
      t.datetime "created_at"
      t.datetime "updated_at"
    end

    add_index "say_when_jobs", ["next_fire_at"], name: "index_say_when_jobs_on_next_fire_at"
    add_index "say_when_jobs", ["status"], name: "index_say_when_jobs_on_status"

    create_table "schedules", force: true do |t|
      t.integer "series_id"
      t.integer "day"
      t.integer "hour"
      t.datetime "created_at"
      t.datetime "updated_at"
    end

    add_index "schedules", ["series_id"], name: "index_schedules_on_series_id"

    create_table "seasons_series", id: false, force: true do |t|
      t.integer "season_id"
      t.integer "series_id"
    end

    create_table "series", force: true do |t|
      t.integer "account_id"
      t.string "title"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.text "short_description"
      t.text "description"
      t.string "frequency"
      t.text "production_notes"
      t.integer "creator_id"
      t.datetime "deleted_at"
      t.string "file_prefix"
      t.string "time_zone"
      t.integer "episode_start_number"
      t.datetime "episode_start_at"
      t.string "subscription_approval_status"
      t.integer "evergreen_piece_id"
      t.integer "due_before_hours"
      t.datetime "prx_billing_at"
      t.integer "promos_days_early"
      t.datetime "subauto_bill_me_at"
      t.datetime "subscriber_only_at"
      t.string "app_version", default: "v3", null: false
      t.boolean "check_language", default: false
      t.boolean "use_porter"
    end

    add_index "series", ["account_id"], name: "index_series_on_account_id"

    create_table "series_files", force: true do |t|
      t.datetime "created_at"
      t.datetime "updated_at"
      t.integer "series_id"
      t.integer "size"
      t.string "content_type"
      t.string "filename"
      t.string "label"
    end

    add_index "series_files", ["series_id"], name: "series_files_series_id_fk"

    create_table "series_images", force: true do |t|
      t.integer "parent_id"
      t.string "content_type"
      t.string "filename"
      t.string "thumbnail"
      t.integer "size"
      t.integer "width"
      t.integer "height"
      t.float "aspect_ratio"
      t.integer "series_id"
      t.string "caption"
      t.string "credit"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.text "upload_path"
      t.string "status"
      t.string "purpose"
    end

    add_index "series_images", ["series_id"], name: "series_images_series_id_fk"

    create_table "site_message_receptions", force: true do |t|
      t.integer "site_message_id"
      t.integer "recipient_id"
      t.datetime "read_at"
      t.datetime "dismissed_at"
      t.datetime "created_at"
      t.datetime "updated_at"
    end

    create_table "site_messages", force: true do |t|
      t.integer "sender_id"
      t.string "body"
      t.datetime "published_at"
      t.datetime "deleted_at"
      t.datetime "created_at"
      t.datetime "updated_at"
    end

    create_table "skills", force: true do |t|
      t.string "name"
      t.integer "user_id"
    end

    add_index "skills", ["user_id"], name: "skills_user_id_fk"

    create_table "station_accounts", force: true do |t|
      t.string "name"
    end

    create_table "station_formats", force: true do |t|
      t.string "format"
      t.integer "station_id"
    end

    add_index "station_formats", ["station_id"], name: "station_formats_station_id_fk"

    create_table "story_distributions", force: true do |t|
      t.string "type"
      t.integer "distribution_id"
      t.integer "piece_id"
      t.string "url"
      t.string "guid"
      t.text "properties"
      t.datetime "created_at"
      t.datetime "updated_at"
    end

    add_index "story_distributions", ["distribution_id", "piece_id"], name: "index_story_distributions_on_distribution_id_and_piece_id"

    create_table "subscription_invoices", force: true do |t|
      t.integer "subscription_id"
      t.date "date"
      t.string "type"
    end

    create_table "subscription_line_items", force: true do |t|
      t.string "description"
      t.integer "subscription_invoice_id"
      t.integer "discount_id"
    end

    create_table "subscription_prices", force: true do |t|
      t.integer "series_id"
      t.integer "pricing_tier_id"
      t.integer "value"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.integer "season_id"
    end

    create_table "subscription_seasons", force: true do |t|
      t.string "label"
      t.date "start_date"
      t.date "end_date"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.date "pricing_due_date"
      t.boolean "nonstandard"
    end

    create_table "subscriptions", force: true do |t|
      t.integer "series_id"
      t.integer "account_id"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.integer "end_air_days"
      t.string "delivery_audio_type"
      t.datetime "file_delivery_at"
      t.integer "cart_number_start"
      t.integer "cart_number_factor"
      t.string "delivery_filename_format"
      t.string "delivery_transport_method"
      t.integer "audio_version_template_id"
      t.string "producer_app_id"
      t.date "start_date"
      t.date "end_date"
      t.boolean "approved_by_subscriber"
      t.boolean "approved_by_producer"
      t.datetime "agreed_to_terms_at"
      t.integer "subscriber_id"
      t.datetime "approved_at"
      t.integer "days_early"
      t.integer "days_late"
      t.string "billing_name"
      t.string "billing_phone"
      t.string "billing_email"
      t.integer "promos_cart_number_start"
      t.integer "promos_cart_number_factor"
      t.string "billing_frequency"
      t.integer "tsr"
      t.text "notes"
      t.integer "active_deliveries_max", default: 0
      t.integer "start_air_days_early", default: 0
      t.boolean "no_pad_byte", default: false
      t.text "selected_hours"
    end

    add_index "subscriptions", ["account_id"], name: "index_subscriptions_on_account_id"
    add_index "subscriptions", ["series_id"], name: "index_subscriptions_on_series_id"

    create_table "taggings", force: true do |t|
      t.integer "tag_id"
      t.integer "taggable_id"
      t.string "taggable_type"
      t.datetime "created_at"
    end

    add_index "taggings", ["tag_id"], name: "index_taggings_on_tag_id"
    add_index "taggings", ["taggable_id", "taggable_type"], name: "index_taggings_on_taggable_id_and_taggable_type"

    create_table "tags", force: true do |t|
      t.string "name"
    end

    create_table "tones", force: true do |t|
      t.integer "piece_id"
      t.string "name"
    end

    add_index "tones", ["name"], name: "name_idx"
    add_index "tones", ["piece_id"], name: "tones_piece_id_fk"

    create_table "topics", force: true do |t|
      t.integer "piece_id"
      t.string "name"
    end

    add_index "topics", ["name"], name: "name_idx"
    add_index "topics", ["piece_id"], name: "topics_piece_id_fk"

    create_table "user_images", force: true do |t|
      t.integer "parent_id"
      t.string "content_type"
      t.string "filename"
      t.string "thumbnail"
      t.integer "size"
      t.integer "width"
      t.integer "height"
      t.float "aspect_ratio"
      t.integer "user_id"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.text "upload_path"
      t.string "status"
      t.string "caption"
      t.string "credit"
      t.string "purpose"
    end

    add_index "user_images", ["updated_at"], name: "index_user_images_on_updated_at"
    add_index "user_images", ["user_id"], name: "user_images_user_id_fk"

    create_table "users", force: true do |t|
      t.string "login"
      t.string "email"
      t.string "crypted_password", limit: 40
      t.string "salt", limit: 40
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string "remember_token"
      t.datetime "remember_token_expires_at"
      t.string "activation_code", limit: 40
      t.datetime "activated_at"
      t.string "password_reset_code", limit: 40
      t.string "first_name"
      t.string "last_name"
      t.datetime "deleted_at"
      t.datetime "migrated_at"
      t.string "old_password"
      t.datetime "user_agreement_at"
      t.datetime "subscribed_at"
      t.string "day_phone"
      t.string "eve_phone"
      t.string "im_name"
      t.text "bio"
      t.integer "account_id"
      t.string "title"
      t.string "favorite_shows"
      t.string "influences"
      t.boolean "available"
      t.boolean "has_car"
      t.string "will_travel"
      t.string "aired_on"
      t.string "im_service"
      t.string "role"
      t.string "time_zone"
      t.integer "merged_into_user_id"
      t.string "ftp_password"
      t.integer "daily_message_quota"
      t.string "category"
      t.datetime "suspended_at"
      t.string "reset_password_token"
      t.datetime "reset_password_sent_at"
      t.boolean "id_admin"
    end

    add_index "users", ["account_id"], name: "index_users_on_account_id"
    add_index "users", ["activation_code"], name: "activation_code_idx"
    add_index "users", ["deleted_at"], name: "deleted_at_idx"
    add_index "users", ["email"], name: "users_email_idx"
    add_index "users", ["login"], name: "login_idx"
    add_index "users", ["remember_token"], name: "remember_token_idx"
    add_index "users", ["reset_password_token"], name: "users_unique_reset_password_token_idx", unique: true

    create_table "websites", force: true do |t|
      t.integer "browsable_id"
      t.string "browsable_type"
      t.string "url"
    end

    create_table "work_experiences", force: true do |t|
      t.string "position"
      t.string "company"
      t.string "description"
      t.boolean "current"
      t.date "started_on"
      t.date "ended_on"
      t.integer "user_id"
    end

    add_index "work_experiences", ["user_id"], name: "work_experiences_user_id_fk"
  end
end
