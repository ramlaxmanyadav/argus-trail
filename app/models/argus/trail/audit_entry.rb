module Argus
  module Trail
    # Immutable log of every role assignment/revocation on an actor, and every
    # permission granted/revoked on a role. `subject` is the actor for
    # role_assigned/role_revoked events, or the Role for
    # permission_granted/permission_revoked events.
    class AuditEntry < ApplicationRecord
      serialize :metadata, coder: JSON

      belongs_to :subject, polymorphic: true
      belongs_to :changed_by, polymorphic: true, optional: true
      belongs_to :role, class_name: Argus::Trail.config.role_class_name, optional: true
      belongs_to :permission, class_name: Argus::Trail.config.permission_class_name, optional: true

      validates :event_type, presence: true

      scope :recent, -> { order(created_at: :desc) }

      def role_name = role&.name || metadata&.dig("role_name")
      def permission_name = permission&.name || metadata&.dig("permission_name")

      def changed_by_label
        return "System" if changed_by.nil?
        changed_by.try(:argus_trail_display_name) ||
          changed_by.try(:name) ||
          changed_by.try(:email) ||
          "#{changed_by.class.name} ##{changed_by.id}"
      end

      def subject_label
        subject.try(:argus_trail_display_name) ||
          subject.try(:name) ||
          subject.try(:email) ||
          "#{subject.class.name} ##{subject.id}"
      end
    end
  end
end
