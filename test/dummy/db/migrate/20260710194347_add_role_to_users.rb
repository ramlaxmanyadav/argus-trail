class AddRoleToUsers < ActiveRecord::Migration[8.1]
  def change
    add_reference :users, :role, null: true, foreign_key: { to_table: :argus_trail_roles }
  end
end
