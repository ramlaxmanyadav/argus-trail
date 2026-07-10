module Argus
  module Trail
    class Permission < ApplicationRecord
      has_many :role_permissions, dependent: :destroy
      has_many :roles, through: :role_permissions

      validates :name, presence: true, uniqueness: true
      validates :description, presence: true
    end
  end
end
