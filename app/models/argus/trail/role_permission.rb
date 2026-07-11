module Argus
  module Trail
    class RolePermission < ApplicationRecord
      belongs_to :role, class_name: Argus::Trail.config.role_class_name
      belongs_to :permission, class_name: Argus::Trail.config.permission_class_name

      validates :permission_id, uniqueness: { scope: :role_id }
    end
  end
end
