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

ActiveRecord::Schema[7.2].define(version: 2026_06_15_150000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "campaigns", force: :cascade do |t|
    t.string "title", null: false
    t.integer "status", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "recipients_count", default: 0, null: false
    t.integer "processed_count", default: 0, null: false
    t.integer "failed_count", default: 0, null: false
    t.text "body"
    t.check_constraint "status = ANY (ARRAY[0, 1, 2])", name: "campaigns_status_range"
  end

  create_table "recipients", force: :cascade do |t|
    t.bigint "campaign_id", null: false
    t.string "name", null: false
    t.string "email", null: false
    t.integer "status", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["campaign_id", "status"], name: "index_recipients_on_campaign_id_and_status"
    t.check_constraint "status = ANY (ARRAY[0, 1, 2])", name: "recipients_status_range"
  end

  add_foreign_key "recipients", "campaigns", on_delete: :cascade
end
