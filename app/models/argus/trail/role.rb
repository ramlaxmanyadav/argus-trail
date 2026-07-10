module Argus
  module Trail
    class Role < ApplicationRecord
      has_many :role_permissions, dependent: :destroy
      has_many :permissions, through: :role_permissions

      # class_name as a string is only constantized when the association is
      # actually used, so this is safe even before the host's actor class loads.
      has_many :actors, class_name: Argus::Trail.config.actor_class_name, foreign_key: :role_id

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

          Permission.where(id: added_ids).find_each do |permission|
            record_permission_change("permission_granted", permission, changed_by)
          end

          Permission.where(id: removed_ids).find_each do |permission|
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
