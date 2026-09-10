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

ActiveRecord::Schema[8.1].define(version: 2026_09_08_000001) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "citext"
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
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

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "addresses", force: :cascade do |t|
    t.string "apartment"
    t.string "city", default: "CABA", null: false
    t.datetime "created_at", null: false
    t.string "floor"
    t.boolean "is_default", default: false, null: false
    t.string "neighborhood", null: false
    t.text "notes"
    t.string "number", null: false
    t.string "phone", null: false
    t.string "postal_code", null: false
    t.string "recipient_name", null: false
    t.string "street", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_addresses_on_user_id"
  end

  create_table "admin_users", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.citext "email", null: false
    t.string "locale", default: "es", null: false
    t.string "name", null: false
    t.string "password_digest", null: false
    t.string "role", default: "operator", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_admin_users_on_email", unique: true
  end

  create_table "audit_logs", force: :cascade do |t|
    t.string "action", null: false
    t.bigint "admin_user_id"
    t.jsonb "change_set", default: {}, null: false
    t.datetime "created_at", null: false
    t.bigint "subject_id"
    t.string "subject_type"
    t.index ["admin_user_id"], name: "index_audit_logs_on_admin_user_id"
    t.index ["created_at"], name: "index_audit_logs_on_created_at"
    t.index ["subject_type", "subject_id"], name: "index_audit_logs_on_subject_type_and_subject_id"
  end

  create_table "cart_items", force: :cascade do |t|
    t.bigint "cart_id", null: false
    t.bigint "catalog_item_id"
    t.datetime "created_at", null: false
    t.integer "quantity", default: 1, null: false
    t.bigint "template_id", null: false
    t.bigint "template_size_id", null: false
    t.datetime "updated_at", null: false
    t.index ["cart_id"], name: "index_cart_items_on_cart_id"
    t.index ["catalog_item_id"], name: "index_cart_items_on_catalog_item_id"
    t.index ["template_id"], name: "index_cart_items_on_template_id"
    t.index ["template_size_id"], name: "index_cart_items_on_template_size_id"
  end

  create_table "carts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "owner_id", null: false
    t.string "owner_type", null: false
    t.datetime "updated_at", null: false
    t.index ["owner_type", "owner_id"], name: "index_carts_on_owner_type_and_owner_id", unique: true
  end

  create_table "catalog_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "description", default: {}, null: false
    t.integer "position", default: 0, null: false
    t.integer "price_cents", default: 0, null: false
    t.boolean "published", default: false, null: false
    t.string "slug", null: false
    t.string "tags", default: [], null: false, array: true
    t.bigint "template_id", null: false
    t.jsonb "title", default: {}, null: false
    t.datetime "updated_at", null: false
    t.index ["published", "position"], name: "index_catalog_items_on_published_and_position"
    t.index ["slug"], name: "index_catalog_items_on_slug", unique: true
    t.index ["tags"], name: "index_catalog_items_on_tags", using: :gin
    t.index ["template_id"], name: "index_catalog_items_on_template_id"
  end

  create_table "conversations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "last_message_at"
    t.integer "unread_for_admin", default: 0, null: false
    t.integer "unread_for_user", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_conversations_on_user_id", unique: true
  end

  create_table "coupon_redemptions", force: :cascade do |t|
    t.bigint "coupon_id", null: false
    t.datetime "created_at", null: false
    t.integer "discount_cents", null: false
    t.bigint "order_id", null: false
    t.datetime "restored_at"
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["coupon_id", "order_id"], name: "index_coupon_redemptions_on_coupon_id_and_order_id", unique: true
    t.index ["coupon_id"], name: "index_coupon_redemptions_on_coupon_id"
    t.index ["order_id"], name: "index_coupon_redemptions_on_order_id"
    t.index ["user_id"], name: "index_coupon_redemptions_on_user_id"
  end

  create_table "coupons", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.string "discount_type", null: false
    t.integer "discount_value", null: false
    t.integer "max_uses"
    t.integer "min_order_cents"
    t.text "note"
    t.bigint "owner_id"
    t.string "source", default: "manual", null: false
    t.datetime "updated_at", null: false
    t.integer "used_count", default: 0, null: false
    t.datetime "valid_from"
    t.datetime "valid_until"
    t.index ["code"], name: "index_coupons_on_code", unique: true
    t.index ["owner_id"], name: "index_coupons_on_owner_id"
  end

  create_table "designs", force: :cascade do |t|
    t.bigint "byte_size"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.datetime "enhanced_at"
    t.integer "enhanced_height_px"
    t.integer "enhanced_width_px"
    t.text "enhancement_note"
    t.string "enhancement_provider"
    t.datetime "enhancement_requested_at"
    t.string "enhancement_status", default: "none", null: false
    t.integer "height_px"
    t.text "license_note"
    t.string "moderation_status", default: "pending", null: false
    t.string "original_filename"
    t.bigint "owner_id"
    t.string "owner_type"
    t.string "source", default: "user", null: false
    t.datetime "updated_at", null: false
    t.integer "width_px"
    t.index ["enhancement_status"], name: "index_designs_on_enhancement_status"
    t.index ["owner_type", "owner_id"], name: "index_designs_on_owner_type_and_owner_id"
  end

  create_table "guest_sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.datetime "last_seen_at"
    t.datetime "merged_at"
    t.bigint "merged_into_user_id"
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_guest_sessions_on_expires_at"
    t.index ["token"], name: "index_guest_sessions_on_token", unique: true
  end

  create_table "messages", force: :cascade do |t|
    t.text "body", default: "", null: false
    t.bigint "conversation_id", null: false
    t.datetime "created_at", null: false
    t.bigint "order_id"
    t.datetime "read_at"
    t.bigint "sender_id", null: false
    t.string "sender_type", null: false
    t.datetime "updated_at", null: false
    t.index ["conversation_id", "created_at"], name: "index_messages_on_conversation_id_and_created_at"
    t.index ["conversation_id"], name: "index_messages_on_conversation_id"
    t.index ["order_id"], name: "index_messages_on_order_id"
  end

  create_table "order_items", force: :cascade do |t|
    t.bigint "catalog_item_id"
    t.datetime "created_at", null: false
    t.integer "line_total_cents", null: false
    t.bigint "order_id", null: false
    t.integer "quantity", default: 1, null: false
    t.integer "sides_count", default: 0, null: false
    t.jsonb "snapshot", default: {}, null: false
    t.bigint "template_id", null: false
    t.bigint "template_size_id", null: false
    t.integer "unit_price_cents", null: false
    t.datetime "updated_at", null: false
    t.index ["catalog_item_id"], name: "index_order_items_on_catalog_item_id"
    t.index ["order_id"], name: "index_order_items_on_order_id"
    t.index ["template_id"], name: "index_order_items_on_template_id"
    t.index ["template_size_id"], name: "index_order_items_on_template_size_id"
  end

  create_table "order_status_transitions", force: :cascade do |t|
    t.bigint "actor_id"
    t.string "actor_type"
    t.datetime "created_at", null: false
    t.string "from_status"
    t.bigint "order_id", null: false
    t.text "reason"
    t.string "to_status", null: false
    t.index ["order_id"], name: "index_order_status_transitions_on_order_id"
  end

  create_table "orders", force: :cascade do |t|
    t.datetime "cancelled_at"
    t.string "coupon_code"
    t.bigint "coupon_id"
    t.datetime "created_at", null: false
    t.string "currency", default: "ARS", null: false
    t.text "customer_notes"
    t.datetime "delivered_at"
    t.integer "discount_cents", default: 0, null: false
    t.string "locale", default: "es", null: false
    t.boolean "low_quality_artwork", default: false, null: false
    t.string "number", null: false
    t.datetime "paid_at"
    t.datetime "placed_at"
    t.text "problem_note"
    t.text "rejection_reason"
    t.boolean "requires_moderation", default: false, null: false
    t.boolean "rush", default: false, null: false
    t.integer "rush_fee_cents", default: 0, null: false
    t.jsonb "shipping_address", default: {}, null: false
    t.integer "shipping_fee_cents", default: 0, null: false
    t.string "shipping_method", null: false
    t.string "status", default: "draft", null: false
    t.integer "subtotal_cents", default: 0, null: false
    t.integer "total_cents", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["coupon_id"], name: "index_orders_on_coupon_id"
    t.index ["low_quality_artwork"], name: "index_orders_on_low_quality_artwork", where: "low_quality_artwork"
    t.index ["number"], name: "index_orders_on_number", unique: true
    t.index ["status"], name: "index_orders_on_status"
    t.index ["user_id", "created_at"], name: "index_orders_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_orders_on_user_id"
  end

  create_table "payment_events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "event_type"
    t.bigint "order_id"
    t.jsonb "payload", default: {}, null: false
    t.datetime "processed_at"
    t.string "provider", null: false
    t.string "provider_event_id", null: false
    t.string "result"
    t.datetime "updated_at", null: false
    t.index ["order_id"], name: "index_payment_events_on_order_id"
    t.index ["provider", "provider_event_id"], name: "index_payment_events_on_provider_and_provider_event_id", unique: true
  end

  create_table "payments", force: :cascade do |t|
    t.integer "amount_cents", null: false
    t.datetime "approved_at"
    t.string "checkout_url"
    t.datetime "created_at", null: false
    t.string "currency", default: "ARS", null: false
    t.string "external_reference", null: false
    t.string "flow", default: "redirect", null: false
    t.bigint "order_id", null: false
    t.string "provider", null: false
    t.string "provider_payment_id"
    t.string "provider_preference_id"
    t.text "qr_data"
    t.jsonb "raw_payload", default: {}, null: false
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["external_reference"], name: "index_payments_on_external_reference"
    t.index ["order_id"], name: "index_payments_on_order_id"
    t.index ["provider", "provider_payment_id"], name: "index_payments_on_provider_and_provider_payment_id", unique: true, where: "(provider_payment_id IS NOT NULL)"
  end

  create_table "placements", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "design_id", null: false
    t.bigint "placeable_id", null: false
    t.string "placeable_type", null: false
    t.bigint "print_area_id", null: false
    t.decimal "rotation", precision: 8, scale: 3, default: "0.0", null: false
    t.decimal "scale", precision: 8, scale: 6, default: "1.0", null: false
    t.datetime "updated_at", null: false
    t.decimal "x", precision: 8, scale: 6, default: "0.5", null: false
    t.decimal "y", precision: 8, scale: 6, default: "0.5", null: false
    t.index ["design_id"], name: "index_placements_on_design_id"
    t.index ["placeable_type", "placeable_id"], name: "index_placements_on_placeable_type_and_placeable_id"
    t.index ["print_area_id"], name: "index_placements_on_print_area_id"
  end

  create_table "print_areas", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.decimal "h", precision: 8, scale: 6, default: "0.5", null: false
    t.decimal "height_mm", precision: 8, scale: 2, default: "380.0", null: false
    t.integer "min_dpi", default: 150, null: false
    t.integer "mockup_height_px"
    t.integer "mockup_width_px"
    t.string "side", null: false
    t.bigint "template_id", null: false
    t.datetime "updated_at", null: false
    t.decimal "w", precision: 8, scale: 6, default: "0.5", null: false
    t.decimal "width_mm", precision: 8, scale: 2, default: "280.0", null: false
    t.decimal "x", precision: 8, scale: 6, default: "0.25", null: false
    t.decimal "y", precision: 8, scale: 6, default: "0.2", null: false
    t.index ["template_id", "side"], name: "index_print_areas_on_template_id_and_side", unique: true
    t.index ["template_id"], name: "index_print_areas_on_template_id"
  end

  create_table "reviews", force: :cascade do |t|
    t.text "body"
    t.bigint "coupon_id"
    t.datetime "created_at", null: false
    t.bigint "order_id", null: false
    t.boolean "published", default: true, null: false
    t.integer "rating", null: false
    t.text "rejection_reason"
    t.datetime "reviewed_at"
    t.bigint "reviewed_by_id"
    t.string "status", default: "pending", null: false
    t.integer "submission_count", default: 1, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["coupon_id"], name: "index_reviews_on_coupon_id"
    t.index ["order_id"], name: "index_reviews_on_order_id", unique: true
    t.index ["reviewed_by_id"], name: "index_reviews_on_reviewed_by_id"
    t.index ["status", "published"], name: "index_reviews_on_status_and_published"
    t.index ["user_id"], name: "index_reviews_on_user_id"
  end

  create_table "settings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.jsonb "value"
    t.index ["key"], name: "index_settings_on_key", unique: true
  end

  create_table "template_sizes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "label", null: false
    t.integer "position", default: 0, null: false
    t.date "restock_at"
    t.integer "stock", default: 0, null: false
    t.bigint "template_id", null: false
    t.datetime "updated_at", null: false
    t.index ["template_id", "label"], name: "index_template_sizes_on_template_id_and_label", unique: true
    t.index ["template_id"], name: "index_template_sizes_on_template_id"
  end

  create_table "templates", force: :cascade do |t|
    t.boolean "active", default: false, null: false
    t.integer "base_price_cents", default: 0, null: false
    t.string "color_hex", default: "#ffffff", null: false
    t.string "color_name", null: false
    t.datetime "created_at", null: false
    t.jsonb "description", default: {}, null: false
    t.string "kind", default: "t-shirt", null: false
    t.jsonb "name", default: {}, null: false
    t.integer "position", default: 0, null: false
    t.integer "print_price_one_side_cents", default: 0, null: false
    t.integer "print_price_two_sides_cents", default: 0, null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["active", "position"], name: "index_templates_on_active_and_position"
    t.index ["slug"], name: "index_templates_on_slug", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.datetime "confirmed_at"
    t.datetime "created_at", null: false
    t.citext "email", null: false
    t.string "first_name", default: "", null: false
    t.string "google_uid"
    t.string "last_name", default: "", null: false
    t.datetime "last_sign_in_at"
    t.string "locale", default: "es", null: false
    t.string "password_digest"
    t.string "phone"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["google_uid"], name: "index_users_on_google_uid", unique: true, where: "(google_uid IS NOT NULL)"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "addresses", "users"
  add_foreign_key "audit_logs", "admin_users"
  add_foreign_key "cart_items", "carts"
  add_foreign_key "cart_items", "catalog_items"
  add_foreign_key "cart_items", "template_sizes"
  add_foreign_key "cart_items", "templates"
  add_foreign_key "catalog_items", "templates"
  add_foreign_key "conversations", "users"
  add_foreign_key "coupon_redemptions", "coupons"
  add_foreign_key "coupon_redemptions", "orders"
  add_foreign_key "coupon_redemptions", "users"
  add_foreign_key "coupons", "users", column: "owner_id"
  add_foreign_key "messages", "conversations"
  add_foreign_key "messages", "orders"
  add_foreign_key "order_items", "catalog_items"
  add_foreign_key "order_items", "orders"
  add_foreign_key "order_items", "template_sizes"
  add_foreign_key "order_items", "templates"
  add_foreign_key "order_status_transitions", "orders"
  add_foreign_key "orders", "coupons"
  add_foreign_key "orders", "users"
  add_foreign_key "payment_events", "orders"
  add_foreign_key "payments", "orders"
  add_foreign_key "placements", "designs"
  add_foreign_key "placements", "print_areas"
  add_foreign_key "print_areas", "templates"
  add_foreign_key "reviews", "admin_users", column: "reviewed_by_id"
  add_foreign_key "reviews", "coupons"
  add_foreign_key "reviews", "orders"
  add_foreign_key "reviews", "users"
  add_foreign_key "template_sizes", "templates"
end
