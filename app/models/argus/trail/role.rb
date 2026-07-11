module Argus
  module Trail
    class Role < ApplicationRecord
      has_many :role_permissions, class_name: Argus::Trail.config.role_permission_class_name, dependent: :destroy
      has_many :permissions, through: :role_permissions

      # The join table itself is polymorphic (no migration needed on the
      # host's actor table), but a has_many :through needs one concrete type
      # to instantiate results as, hence source_type here.
      has_many :role_assignments, class_name: "Argus::Trail::RoleAssignment", dependent: :destroy
      has_many :actors, through: :role_assignments, source: :actor, source_type: Argus::Trail.config.actor_class_name

      validates :name, presence: true, uniqueness: true
      validates :description, presence: true

      # Diffs the requested permission ids against the role's current ones and
      # writes one AuditEntry per addition/removal, so the audit log captures
      # exactly which permissions were granted or revoked (not just "something changed").
      def sync_permissions!(new_permission_ids, changed_by: Argus::Trail.config.changed_by_resolver.call)
        new_ids = Array(new_permission_ids).map(&:to_i).reject(&:zero?)
        current_ids = permission_ids

        added_ids   = new_ids - current_ids
        removed_ids = current_ids - new_ids

        transaction do
          self.permission_ids = new_ids

          Argus::Trail.config.permission_class.where(id: added_ids).find_each do |permission|
            record_permission_change("permission_granted", permission, changed_by)
          end

          Argus::Trail.config.permission_class.where(id: removed_ids).find_each do |permission|
            record_permission_change("permission_revoked", permission, changed_by)
          end
        end
      end

      private

      def record_permission_change(event_type, permission, changed_by)
        AuditEntry.create!(
          event_type:    event_type,
          subject:       self,
          role_id:       id,
          permission_id: permission.id,
          changed_by:    changed_by,
          metadata:      { "role_name" => name, "permission_name" => permission.name }
        )
      end
    end
  end
end
