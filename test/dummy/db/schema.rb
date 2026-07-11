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

ActiveRecord::Schema[8.1].define(version: 2026_07_10_194346) do
  create_table "argus_trail_audit_entries", force: :cascade do |t|
    t.integer "changed_by_id"
    t.string "changed_by_type"
    t.datetime "created_at", null: false
    t.string "event_type", null: false
    t.text "metadata"
    t.integer "permission_id"
    t.integer "role_id"
    t.integer "subject_id", null: false
    t.string "subject_type", null: false
    t.index [ "changed_by_type", "changed_by_id" ], name: "index_argus_trail_audit_entries_on_changed_by"
    t.index [ "event_type" ], name: "index_argus_trail_audit_entries_on_event_type"
    t.index [ "permission_id" ], name: "index_argus_trail_audit_entries_on_permission_id"
    t.index [ "role_id" ], name: "index_argus_trail_audit_entries_on_role_id"
    t.index [ "subject_type", "subject_id" ], name: "index_argus_trail_audit_entries_on_subject"
  end

  create_table "argus_trail_permissions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "description"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index [ "name" ], name: "index_argus_trail_permissions_on_name", unique: true
  end

  create_table "argus_trail_role_assignments", force: :cascade do |t|
    t.integer "actor_id", null: false
    t.string "actor_type", null: false
    t.datetime "created_at", null: false
    t.integer "role_id", null: false
    t.datetime "updated_at", null: false
    t.index [ "actor_type", "actor_id", "role_id" ], name: "index_argus_trail_role_assignments_on_actor_and_role", unique: true
    t.index [ "actor_type", "actor_id" ], name: "index_argus_trail_role_assignments_on_actor"
    t.index [ "role_id" ], name: "index_argus_trail_role_assignments_on_role_id"
  end

  create_table "argus_trail_role_permissions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "permission_id", null: false
    t.integer "role_id", null: false
    t.datetime "updated_at", null: false
    t.index [ "permission_id" ], name: "index_argus_trail_role_permissions_on_permission_id"
    t.index [ "role_id", "permission_id" ], name: "index_argus_trail_role_permissions_on_role_id_and_permission_id", unique: true
    t.index [ "role_id" ], name: "index_argus_trail_role_permissions_on_role_id"
  end

  create_table "argus_trail_roles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "description"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index [ "name" ], name: "index_argus_trail_roles_on_name", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.boolean "admin", default: false
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "name"
    t.datetime "updated_at", null: false
  end

  add_foreign_key "argus_trail_audit_entries", "argus_trail_permissions", column: "permission_id"
  add_foreign_key "argus_trail_audit_entries", "argus_trail_roles", column: "role_id"
  add_foreign_key "argus_trail_role_assignments", "argus_trail_roles", column: "role_id"
  add_foreign_key "argus_trail_role_permissions", "argus_trail_permissions", column: "permission_id"
  add_foreign_key "argus_trail_role_permissions", "argus_trail_roles", column: "role_id"
end
