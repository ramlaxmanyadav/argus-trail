module Argus
  module Trail
    class RolePermission < ApplicationRecord
      belongs_to :role
      belongs_to :permission

      validates :permission_id, uniqueness: { scope: :role_id }
    end
  end
end
