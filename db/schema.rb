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

ActiveRecord::Schema[7.2].define(version: 2024_12_21_062421) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "awakenings", force: :cascade do |t|
    t.bigint "sleep_log_id"
    t.integer "awakenings_count"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["sleep_log_id"], name: "index_awakenings_on_sleep_log_id"
  end

  create_table "comments", force: :cascade do |t|
    t.bigint "sleep_log_id"
    t.text "comment"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["sleep_log_id"], name: "index_comments_on_sleep_log_id"
  end

  create_table "napping_times", force: :cascade do |t|
    t.bigint "sleep_log_id"
    t.integer "napping_time"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["sleep_log_id"], name: "index_napping_times_on_sleep_log_id"
  end

  create_table "sleep_logs", force: :cascade do |t|
    t.bigint "user_id"
    t.datetime "go_to_bed_at"
    t.datetime "fell_asleep_at"
    t.datetime "woke_up_at"
    t.datetime "leave_bed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.date "date"
    t.index ["user_id"], name: "index_sleep_logs_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "name", null: false
    t.string "email"
    t.string "encrypted_password", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "awakenings", "sleep_logs"
  add_foreign_key "comments", "sleep_logs"
  add_foreign_key "napping_times", "sleep_logs"
  add_foreign_key "sleep_logs", "users"
end
