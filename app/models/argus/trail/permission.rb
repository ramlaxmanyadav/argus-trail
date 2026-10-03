module Argus
  module Trail
    class Permission < ApplicationRecord
      has_many :role_permissions, class_name: Argus::Trail.config.role_permission_class_name, dependent: :destroy
      has_many :roles, through: :role_permissions

      before_validation :set_derived_attributes

      validates :name, presence: true, uniqueness: true
      validates :description, presence: true
      validates :action, uniqueness: { scope: :module_name }, if: -> { module_name.present? }

      scope :module_wise, -> { where.not(module_name: nil) }

      # Groups permissions by `module_name` (e.g. every permission generated
      # from the "admin/accounts" controller) in the order the admin UI
      # renders its checkbox matrix. Manually-created, module-less
      # permissions land together under a `nil` key.
      def self.grouped_by_module
        order(:module_name, :action).group_by(&:module_name)
      end

      def module_permission?
        module_name.present? && action.present?
      end

      def display_name
        return name.humanize unless module_permission?

        "#{module_name.humanize} — #{action.humanize}"
      end

      private

      # Module-wise permissions (created by `rails argus_trail:fetch_permissions`,
      # or by hand) derive their name/description from module_name + action so
      # callers never have to invent one; a manually created, module-less
      # permission just keeps whatever name/description it was given.
      def set_derived_attributes
        return unless module_permission?

        self.name = name.presence || "#{module_name}##{action}"
        self.description = description.presence || "#{action.to_s.humanize} access to #{module_name.to_s.humanize}"
      end
    end
  end
end
