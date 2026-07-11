module Argus
  module Trail
    # Include in your app's user/account model to opt it into role assignment
    # and permission checks:
    #
    #   class User < ApplicationRecord
    #     include Argus::Trail::Actor
    #   end
    #
    # An actor can hold any number of roles (0..N) — there is no separate
    # single-role mode. Assign a lone role by passing a single id to
    # `sync_roles!`.
    module Actor
      extend ActiveSupport::Concern

      included do
        has_many :argus_trail_role_assignments,
                 as: :actor, class_name: "Argus::Trail::RoleAssignment", dependent: :destroy
        has_many :roles, through: :argus_trail_role_assignments, class_name: Argus::Trail.config.role_class_name

        has_many :argus_trail_audit_entries_as_subject,
                 as: :subject, class_name: "Argus::Trail::AuditEntry", dependent: :destroy
        has_many :argus_trail_audit_entries_as_changer,
                 as: :changed_by, class_name: "Argus::Trail::AuditEntry", dependent: :nullify
      end

      def has_permission?(permission_name)
        roles.joins(:permissions).exists?(Argus::Trail.config.permission_class.table_name => { name: permission_name })
      end

      # Diffs the requested role ids against the actor's current ones and
      # writes one AuditEntry per addition/removal, so the audit log captures
      # exactly which roles were assigned or revoked (not just "something changed").
      def sync_roles!(new_role_ids, changed_by: Argus::Trail.config.changed_by_resolver.call)
        new_ids = Array(new_role_ids).map(&:to_i).reject(&:zero?)
        current_ids = role_ids

        added_ids   = new_ids - current_ids
        removed_ids = current_ids - new_ids

        transaction do
          self.role_ids = new_ids

          Argus::Trail.config.role_class.where(id: added_ids).find_each do |role|
            argus_trail_record_role_change("role_assigned", role, changed_by)
          end

          Argus::Trail.config.role_class.where(id: removed_ids).find_each do |role|
            argus_trail_record_role_change("role_revoked", role, changed_by)
          end
        end
      end

      private

      def argus_trail_record_role_change(event_type, role, changed_by)
        Argus::Trail::AuditEntry.create!(
          event_type: event_type,
          subject:    self,
          role_id:    role.id,
          changed_by: changed_by,
          metadata:   { "role_name" => role.name }
        )
      end
    end
  end
end
