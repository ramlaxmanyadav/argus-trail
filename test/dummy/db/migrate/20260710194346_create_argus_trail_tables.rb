class CreateArgusTrailTables < ActiveRecord::Migration[8.1]
  def change
    create_table :argus_trail_roles do |t|
      t.string :name, null: false
      t.string :description
      t.timestamps
    end
    add_index :argus_trail_roles, :name, unique: true

    create_table :argus_trail_permissions do |t|
      t.string :name, null: false
      t.string :description
      t.timestamps
    end
    add_index :argus_trail_permissions, :name, unique: true

    create_table :argus_trail_role_permissions do |t|
      t.references :role, null: false, foreign_key: { to_table: :argus_trail_roles }
      t.references :permission, null: false, foreign_key: { to_table: :argus_trail_permissions }
      t.timestamps
    end
    add_index :argus_trail_role_permissions, [ :role_id, :permission_id ], unique: true,
              name: "index_argus_trail_role_permissions_on_role_id_and_permission_id"

    create_table :argus_trail_audit_entries do |t|
      t.string :event_type, null: false
      t.references :subject, polymorphic: true, null: false
      t.references :changed_by, polymorphic: true, null: true
      t.references :role, foreign_key: { to_table: :argus_trail_roles }
      t.references :from_role, foreign_key: { to_table: :argus_trail_roles }
      t.references :permission, foreign_key: { to_table: :argus_trail_permissions }
      t.text :metadata
      t.datetime :created_at, null: false
    end
    add_index :argus_trail_audit_entries, :event_type
  end
end
