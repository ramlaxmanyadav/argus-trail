module Argus
  module Trail
    # Include in your app's user/account model to opt it into role assignment
    # and permission checks:
    #
    #   class User < ApplicationRecord
    #     include Argus::Trail::Actor
    #   end
    module Actor
      extend ActiveSupport::Concern

      included do
        belongs_to :role, class_name: "Argus::Trail::Role", optional: true

        has_many :argus_trail_audit_entries_as_subject,
                 as: :subject, class_name: "Argus::Trail::AuditEntry", dependent: :destroy
        has_many :argus_trail_audit_entries_as_changer,
                 as: :changed_by, class_name: "Argus::Trail::AuditEntry", dependent: :nullify

        after_update :argus_trail_record_role_change, if: :saved_change_to_role_id?
      end

      def has_permission?(permission_name)
        role&.permissions&.exists?(name: permission_name)
      end

      private

      def argus_trail_record_role_change
        from_id, to_id = saved_change_to_role_id
        from_role = Argus::Trail::Role.find_by(id: from_id)
        to_role   = Argus::Trail::Role.find_by(id: to_id)

        Argus::Trail::AuditEntry.create!(
          event_type:   "role_assigned",
          subject:      self,
          role_id:      to_id,
          from_role_id: from_id,
          changed_by:   Argus::Trail.config.changed_by_resolver.call,
          metadata:     { "from_role_name" => from_role&.name, "to_role_name" => to_role&.name }
        )
      end
    end
  end
end
