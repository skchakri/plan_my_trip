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


ActiveRecord::Schema[8.1].define(version: 2026_06_24_120000) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  create_table "action_mailbox_inbound_emails", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "message_checksum", null: false
    t.string "message_id", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["message_id", "message_checksum"], name: "index_action_mailbox_inbound_emails_uniqueness", unique: true
  end

  create_table "active_storage_attachments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.uuid "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "activities", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "address"
    t.datetime "created_at", null: false
    t.text "famous_for"
    t.string "group_label"
    t.text "guide_script"
    t.decimal "latitude", precision: 10, scale: 7
    t.string "location_name"
    t.decimal "longitude", precision: 10, scale: 7
    t.string "maps_url"
    t.text "notes"
    t.string "photo_url"
    t.uuid "place_id"
    t.integer "position", default: 0, null: false
    t.string "time_label"
    t.string "title", null: false
    t.uuid "trip_day_id", null: false
    t.string "uber_url"
    t.datetime "updated_at", null: false
    t.index ["place_id"], name: "index_activities_on_place_id"
    t.index ["trip_day_id", "position"], name: "index_activities_on_trip_day_id_and_position"
    t.index ["trip_day_id"], name: "index_activities_on_trip_day_id"
  end

  create_table "ai_calls", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "ai_prompt_id"
    t.datetime "created_at", null: false
    t.text "error"
    t.string "image_url"
    t.integer "input_tokens"
    t.jsonb "input_variables", default: {}, null: false
    t.integer "latency_ms"
    t.jsonb "meta", default: {}, null: false
    t.string "model", null: false
    t.integer "output_tokens"
    t.string "prompt_slug", null: false
    t.string "provider", null: false
    t.text "rendered_system"
    t.text "rendered_user"
    t.text "response_text"
    t.string "status", default: "pending", null: false
    t.uuid "trip_id"
    t.datetime "updated_at", null: false
    t.uuid "user_id"
    t.index ["ai_prompt_id"], name: "index_ai_calls_on_ai_prompt_id"
    t.index ["created_at"], name: "index_ai_calls_on_created_at"
    t.index ["prompt_slug"], name: "index_ai_calls_on_prompt_slug"
    t.index ["status"], name: "index_ai_calls_on_status"
    t.index ["trip_id"], name: "index_ai_calls_on_trip_id"
    t.index ["user_id"], name: "index_ai_calls_on_user_id"
  end

  create_table "ai_prompts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.integer "cache_ttl_seconds"
    t.boolean "cacheable", default: true, null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "kind", default: "text", null: false
    t.integer "max_tokens"
    t.string "model", null: false
    t.string "name", null: false
    t.text "notes"
    t.jsonb "output_schema"
    t.string "provider", default: "anthropic", null: false
    t.string "slug", null: false
    t.text "system_template"
    t.decimal "temperature", precision: 4, scale: 2
    t.datetime "updated_at", null: false
    t.text "user_template", null: false
    t.index ["active"], name: "index_ai_prompts_on_active"
    t.index ["provider"], name: "index_ai_prompts_on_provider"
    t.index ["slug"], name: "index_ai_prompts_on_slug", unique: true
  end

  create_table "app_errors", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "backtrace"
    t.jsonb "context", default: {}, null: false
    t.datetime "created_at", null: false
    t.string "error_class", null: false
    t.string "fingerprint", null: false
    t.datetime "first_occurred_at", null: false
    t.datetime "last_occurred_at", null: false
    t.text "message", null: false
    t.integer "occurrences_count", default: 1, null: false
    t.boolean "resolved", default: false, null: false
    t.datetime "resolved_at"
    t.string "severity", default: "low", null: false
    t.string "source"
    t.datetime "updated_at", null: false
    t.index ["fingerprint"], name: "index_app_errors_on_fingerprint", unique: true
    t.index ["last_occurred_at"], name: "index_app_errors_on_last_occurred_at"
    t.index ["resolved"], name: "index_app_errors_on_resolved"
    t.index ["severity"], name: "index_app_errors_on_severity"
  end

  create_table "app_settings", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "encrypted_value"
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_app_settings_on_key", unique: true
  end

  create_table "booking_claims", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "kind", null: false
    t.text "note"
    t.uuid "trip_id", null: false
    t.datetime "updated_at", null: false
    t.index ["trip_id", "kind"], name: "index_booking_claims_on_trip_id_and_kind", unique: true
    t.index ["trip_id"], name: "index_booking_claims_on_trip_id"
  end

  create_table "brands", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "category", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["category"], name: "index_brands_on_category"
    t.index ["slug"], name: "index_brands_on_slug", unique: true
  end

  create_table "checklist_items", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "activity_label"
    t.string "category"
    t.datetime "created_at", null: false
    t.string "day_label"
    t.datetime "discarded_at"
    t.boolean "packed", default: false, null: false
    t.string "person"
    t.integer "position", default: 0, null: false
    t.string "scope", default: "before_trip", null: false
    t.string "title", null: false
    t.uuid "trip_id", null: false
    t.datetime "updated_at", null: false
    t.index ["discarded_at"], name: "index_checklist_items_on_discarded_at"
    t.index ["trip_id", "category"], name: "index_checklist_items_on_trip_id_and_category"
    t.index ["trip_id", "position"], name: "index_checklist_items_on_trip_id_and_position"
    t.index ["trip_id", "scope"], name: "index_checklist_items_on_trip_id_and_scope"
    t.index ["trip_id"], name: "index_checklist_items_on_trip_id"
  end

  create_table "comments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "activity_id", null: false
    t.uuid "author_id", null: false
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.datetime "discarded_at"
    t.datetime "updated_at", null: false
    t.index ["activity_id", "created_at"], name: "index_comments_on_activity_id_and_created_at"
    t.index ["activity_id"], name: "index_comments_on_activity_id"
    t.index ["author_id"], name: "index_comments_on_author_id"
    t.index ["discarded_at"], name: "index_comments_on_discarded_at"
  end

  create_table "countries", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "calling_code"
    t.string "capital", null: false
    t.string "continent"
    t.datetime "created_at", null: false
    t.string "currency_name"
    t.string "iso2", null: false
    t.string "leader_name"
    t.string "leader_title"
    t.string "name", null: false
    t.string "national_animal"
    t.string "national_anthem"
    t.string "national_bird"
    t.string "national_dish"
    t.string "national_flower"
    t.string "national_motto"
    t.string "national_sport"
    t.string "primary_language"
    t.datetime "updated_at", null: false
    t.index ["continent"], name: "index_countries_on_continent"
    t.index ["iso2"], name: "index_countries_on_iso2", unique: true
    t.index ["name"], name: "index_countries_on_name", unique: true
  end

  create_table "draft_trips", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.datetime "last_step_at"
    t.jsonb "payload", default: {}, null: false
    t.string "step"
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["expires_at"], name: "index_draft_trips_on_expires_at"
    t.index ["user_id"], name: "index_draft_trips_on_user_id", unique: true
  end

  create_table "landmarks", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "continent"
    t.string "country", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["continent"], name: "index_landmarks_on_continent"
    t.index ["name"], name: "index_landmarks_on_name", unique: true
  end

  create_table "notifications", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "actor_id"
    t.string "body"
    t.datetime "created_at", null: false
    t.string "kind", null: false
    t.datetime "read_at"
    t.uuid "recipient_id", null: false
    t.uuid "subject_id"
    t.string "subject_type"
    t.datetime "updated_at", null: false
    t.string "url"
    t.index ["actor_id"], name: "index_notifications_on_actor_id"
    t.index ["recipient_id", "read_at", "created_at"], name: "index_notifications_for_inbox"
    t.index ["recipient_id"], name: "index_notifications_on_recipient_id"
    t.index ["subject_type", "subject_id"], name: "index_notifications_on_subject"
  end

  create_table "people", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "age"
    t.datetime "created_at", null: false
    t.string "interests", default: [], null: false, array: true
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.uuid "trip_id", null: false
    t.datetime "updated_at", null: false
    t.index ["trip_id", "position"], name: "index_people_on_trip_id_and_position"
    t.index ["trip_id"], name: "index_people_on_trip_id"
  end

  create_table "place_reviews", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "author_id", null: false
    t.text "body"
    t.datetime "created_at", null: false
    t.datetime "discarded_at"
    t.uuid "place_id", null: false
    t.integer "rating", null: false
    t.datetime "updated_at", null: false
    t.index ["author_id"], name: "index_place_reviews_on_author_id"
    t.index ["discarded_at"], name: "index_place_reviews_on_discarded_at"
    t.index ["place_id", "author_id"], name: "index_place_reviews_one_per_user", unique: true, where: "(discarded_at IS NULL)"
    t.index ["place_id", "created_at"], name: "index_place_reviews_on_place_id_and_created_at"
    t.index ["place_id"], name: "index_place_reviews_on_place_id"
  end

  create_table "places", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "canonical_name"
    t.decimal "community_rating", precision: 3, scale: 2
    t.integer "community_rating_count", default: 0, null: false
    t.uuid "contributed_by_id"
    t.datetime "created_at", null: false
    t.text "description"
    t.datetime "discarded_at"
    t.text "famous_for"
    t.text "image_attribution"
    t.string "image_source"
    t.string "image_url"
    t.string "kind"
    t.decimal "latitude", precision: 10, scale: 7
    t.decimal "longitude", precision: 10, scale: 7
    t.string "name", null: false
    t.string "region"
    t.string "slug"
    t.jsonb "source_urls", default: {}, null: false
    t.string "tier"
    t.datetime "updated_at", null: false
    t.integer "usage_count", default: 0, null: false
    t.boolean "verified", default: false, null: false
    t.index "lower((name)::text)", name: "index_places_on_lower_name"
    t.index ["contributed_by_id"], name: "index_places_on_contributed_by_id"
    t.index ["discarded_at"], name: "index_places_on_discarded_at"
    t.index ["latitude", "longitude"], name: "index_places_on_lat_lng"
    t.index ["region"], name: "index_places_on_region"
    t.index ["slug"], name: "index_places_on_slug", unique: true, where: "(slug IS NOT NULL)"
    t.index ["tier"], name: "index_places_on_tier"
    t.index ["usage_count"], name: "index_places_on_usage_count"
  end

  create_table "quiz_attempts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "category", null: false
    t.datetime "created_at", null: false
    t.integer "score", default: 0, null: false
    t.integer "total", default: 0, null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["user_id", "category"], name: "index_quiz_attempts_on_user_id_and_category"
    t.index ["user_id"], name: "index_quiz_attempts_on_user_id"
  end

  create_table "quiz_questions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "category", null: false
    t.datetime "created_at", null: false
    t.jsonb "payload", default: {}, null: false
    t.datetime "updated_at", null: false
    t.index ["category"], name: "index_quiz_questions_on_category"
  end

  create_table "reservations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "address"
    t.string "confirmation_number"
    t.datetime "created_at", null: false
    t.datetime "discarded_at"
    t.datetime "end_at"
    t.string "kind", default: "other", null: false
    t.string "location"
    t.text "notes"
    t.jsonb "parsed", default: {}, null: false
    t.text "raw_email"
    t.string "source_from"
    t.datetime "start_at"
    t.string "status", default: "parsing", null: false
    t.string "title"
    t.uuid "trip_day_id"
    t.uuid "trip_id", null: false
    t.datetime "updated_at", null: false
    t.string "vendor"
    t.index ["discarded_at"], name: "index_reservations_on_discarded_at"
    t.index ["trip_day_id"], name: "index_reservations_on_trip_day_id"
    t.index ["trip_id", "confirmation_number"], name: "index_reservations_on_trip_and_confirmation", unique: true, where: "((confirmation_number IS NOT NULL) AND (discarded_at IS NULL))"
    t.index ["trip_id", "kind"], name: "index_reservations_on_trip_id_and_kind"
    t.index ["trip_id"], name: "index_reservations_on_trip_id"
  end

  create_table "route_landmarks", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "discarded_at"
    t.string "image_url"
    t.string "kind", default: "scenic", null: false
    t.decimal "latitude", precision: 10, scale: 7, null: false
    t.decimal "longitude", precision: 10, scale: 7, null: false
    t.string "name", null: false
    t.text "narration", null: false
    t.integer "position", default: 0, null: false
    t.string "source", default: "ai", null: false
    t.uuid "trip_id"
    t.datetime "updated_at", null: false
    t.string "wikipedia_url"
    t.index ["discarded_at"], name: "index_route_landmarks_on_discarded_at"
    t.index ["trip_id", "position"], name: "index_route_landmarks_on_trip_id_and_position"
    t.index ["trip_id"], name: "index_route_landmarks_on_global", where: "(trip_id IS NULL)"
    t.index ["trip_id"], name: "index_route_landmarks_on_trip_id"
  end

  create_table "suggestion_votes", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "suggestion_id", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["suggestion_id", "user_id"], name: "index_suggestion_votes_on_suggestion_id_and_user_id", unique: true
    t.index ["suggestion_id"], name: "index_suggestion_votes_on_suggestion_id"
    t.index ["user_id"], name: "index_suggestion_votes_on_user_id"
  end

  create_table "suggestions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "author_id", null: false
    t.datetime "created_at", null: false
    t.datetime "discarded_at"
    t.text "notes"
    t.string "title", null: false
    t.uuid "trip_day_id", null: false
    t.datetime "updated_at", null: false
    t.string "url"
    t.index ["author_id"], name: "index_suggestions_on_author_id"
    t.index ["discarded_at"], name: "index_suggestions_on_discarded_at"
    t.index ["trip_day_id", "created_at"], name: "index_suggestions_on_trip_day_id_and_created_at"
    t.index ["trip_day_id"], name: "index_suggestions_on_trip_day_id"
  end

  create_table "trails", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "alltrails_url"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.text "notes"
    t.integer "position", default: 0, null: false
    t.uuid "trip_id", null: false
    t.datetime "updated_at", null: false
    t.index ["trip_id", "position"], name: "index_trails_on_trip_id_and_position"
    t.index ["trip_id"], name: "index_trails_on_trip_id"
  end

  create_table "trip_days", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "accent", default: "gold", null: false
    t.datetime "created_at", null: false
    t.date "date"
    t.string "label", null: false
    t.integer "position", default: 0, null: false
    t.text "summary"
    t.string "theme"
    t.string "title", null: false
    t.uuid "trip_id", null: false
    t.datetime "updated_at", null: false
    t.index ["trip_id", "label"], name: "index_trip_days_on_trip_id_and_label"
    t.index ["trip_id", "position"], name: "index_trip_days_on_trip_id_and_position"
    t.index ["trip_id"], name: "index_trip_days_on_trip_id"
  end

  create_table "trip_invitations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "accepted_at"
    t.datetime "created_at", null: false
    t.datetime "declined_at"
    t.datetime "discarded_at"
    t.string "email", null: false
    t.uuid "inviter_id", null: false
    t.string "token", null: false
    t.uuid "trip_id", null: false
    t.datetime "updated_at", null: false
    t.index ["discarded_at"], name: "index_trip_invitations_on_discarded_at"
    t.index ["email"], name: "index_trip_invitations_on_email"
    t.index ["inviter_id"], name: "index_trip_invitations_on_inviter_id"
    t.index ["token"], name: "index_trip_invitations_on_token", unique: true
    t.index ["trip_id"], name: "index_trip_invitations_on_trip_id"
  end

  create_table "trip_memberships", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "accepted_at"
    t.datetime "created_at", null: false
    t.string "custom_title"
    t.string "role", default: "member", null: false
    t.uuid "trip_id", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["trip_id", "user_id"], name: "index_trip_memberships_on_trip_id_and_user_id", unique: true
    t.index ["trip_id"], name: "index_trip_memberships_on_trip_id"
    t.index ["user_id"], name: "index_trip_memberships_on_user_id"
  end

  create_table "trips", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "anchor_label"
    t.decimal "anchor_lat", precision: 9, scale: 6
    t.decimal "anchor_lng", precision: 9, scale: 6
    t.text "body"
    t.string "budget"
    t.jsonb "build_args", default: {}, null: false
    t.text "build_error"
    t.string "build_status", default: "ready", null: false
    t.integer "build_step", default: 0, null: false
    t.datetime "created_at", null: false
    t.boolean "day_trip", default: false, null: false
    t.time "departure_time"
    t.string "destination"
    t.datetime "discarded_at"
    t.date "end_date"
    t.text "excitement_pitch"
    t.string "inbox_token"
    t.jsonb "interests", default: [], null: false
    t.integer "max_radius_km"
    t.string "origin"
    t.uuid "owner_id", null: false
    t.string "pace"
    t.text "preferences"
    t.string "pwa_packing_url"
    t.string "pwa_plan_url"
    t.jsonb "reminders_sent", default: {}, null: false
    t.time "return_time"
    t.datetime "share_revoked_at"
    t.string "share_token"
    t.date "start_date"
    t.string "title", null: false
    t.string "transport_mode"
    t.integer "traveler_count", default: 2, null: false
    t.datetime "updated_at", null: false
    t.decimal "vehicle_mpg", precision: 5, scale: 1
    t.index ["build_status"], name: "index_trips_on_build_status"
    t.index ["day_trip"], name: "index_trips_on_day_trip"
    t.index ["discarded_at"], name: "index_trips_on_discarded_at"
    t.index ["inbox_token"], name: "index_trips_on_inbox_token", unique: true, where: "(inbox_token IS NOT NULL)"
    t.index ["owner_id"], name: "index_trips_on_owner_id"
    t.index ["share_token"], name: "index_trips_on_share_token", unique: true, where: "(share_token IS NOT NULL)"
  end

  create_table "trivia_questions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "answer_index", null: false
    t.text "chain_intro"
    t.datetime "created_at", null: false
    t.string "difficulty"
    t.datetime "discarded_at"
    t.text "fun_fact"
    t.jsonb "options", default: [], null: false
    t.uuid "parent_id"
    t.text "question", null: false
    t.string "source", default: "seed", null: false
    t.string "tag", null: false
    t.uuid "trip_id"
    t.datetime "updated_at", null: false
    t.index ["discarded_at"], name: "index_trivia_questions_on_discarded_at"
    t.index ["parent_id"], name: "index_trivia_questions_on_parent_id"
    t.index ["tag", "trip_id"], name: "index_trivia_questions_on_tag_and_trip_id"
    t.index ["tag"], name: "index_trivia_questions_on_tag"
    t.index ["trip_id"], name: "index_trivia_questions_on_trip_id"
  end

  create_table "trivia_responses", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "answered_at", null: false
    t.boolean "correct", default: false, null: false
    t.datetime "created_at", null: false
    t.uuid "person_id", null: false
    t.uuid "trivia_question_id", null: false
    t.datetime "updated_at", null: false
    t.index ["person_id", "trivia_question_id"], name: "idx_trivia_responses_person_question", unique: true
    t.index ["person_id"], name: "index_trivia_responses_on_person_id"
    t.index ["trivia_question_id"], name: "index_trivia_responses_on_trivia_question_id"
  end

  create_table "us_states", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "abbreviation", null: false
    t.string "capital", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["abbreviation"], name: "index_us_states_on_abbreviation", unique: true
    t.index ["name"], name: "index_us_states_on_name", unique: true
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.boolean "admin", default: false, null: false
    t.boolean "alltrails_pro", default: false, null: false
    t.datetime "created_at", null: false
    t.jsonb "default_interests", default: [], null: false
    t.integer "default_radius_km", default: 80, null: false
    t.datetime "digest_last_sent_at"
    t.datetime "digest_optout_at"
    t.jsonb "discount_memberships", default: {}, null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "home_city"
    t.decimal "home_lat", precision: 9, scale: 6
    t.decimal "home_lng", precision: 9, scale: 6
    t.string "name"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.datetime "updated_at", null: false
    t.index ["admin"], name: "index_users_on_admin", where: "(admin = true)"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "activities", "places"
  add_foreign_key "activities", "trip_days"
  add_foreign_key "ai_calls", "ai_prompts"
  add_foreign_key "ai_calls", "trips"
  add_foreign_key "ai_calls", "users"
  add_foreign_key "booking_claims", "trips"
  add_foreign_key "checklist_items", "trips"
  add_foreign_key "comments", "activities"
  add_foreign_key "comments", "users", column: "author_id"
  add_foreign_key "draft_trips", "users"
  add_foreign_key "notifications", "users", column: "actor_id"
  add_foreign_key "notifications", "users", column: "recipient_id"
  add_foreign_key "people", "trips"
  add_foreign_key "place_reviews", "places"
  add_foreign_key "place_reviews", "users", column: "author_id"
  add_foreign_key "places", "users", column: "contributed_by_id"
  add_foreign_key "quiz_attempts", "users"
  add_foreign_key "reservations", "trip_days"
  add_foreign_key "reservations", "trips"
  add_foreign_key "route_landmarks", "trips"
  add_foreign_key "suggestion_votes", "suggestions"
  add_foreign_key "suggestion_votes", "users"
  add_foreign_key "suggestions", "trip_days"
  add_foreign_key "suggestions", "users", column: "author_id"
  add_foreign_key "trails", "trips"
  add_foreign_key "trip_days", "trips"
  add_foreign_key "trip_invitations", "trips"
  add_foreign_key "trip_invitations", "users", column: "inviter_id"
  add_foreign_key "trip_memberships", "trips"
  add_foreign_key "trip_memberships", "users"
  add_foreign_key "trips", "users", column: "owner_id"
  add_foreign_key "trivia_questions", "trips"
  add_foreign_key "trivia_questions", "trivia_questions", column: "parent_id", on_delete: :cascade
  add_foreign_key "trivia_responses", "people"
  add_foreign_key "trivia_responses", "trivia_questions"
end
