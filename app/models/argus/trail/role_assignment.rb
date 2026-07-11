module Argus
  module Trail
    # Join model between an actor (any class that includes Argus::Trail::Actor)
    # and a Role — polymorphic so any number of actor classes/tables can hold
    # roles without the engine needing a foreign key on each one.
    class RoleAssignment < ApplicationRecord
      belongs_to :actor, polymorphic: true
      belongs_to :role, class_name: Argus::Trail.config.role_class_name

      validates :role_id, uniqueness: { scope: [ :actor_type, :actor_id ] }
    end
  end
end
