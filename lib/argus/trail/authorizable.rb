module Argus
  module Trail
    # Include in any of *your* controllers to gate every action behind a
    # module-wise permission — zero further code required:
    #
    #   class AccountsController < ApplicationController
    #     include Argus::Trail::Authorizable
    #   end
    #
    # The required permission is derived automatically from the controller
    # and action, using the exact same convention
    # `bin/rails argus_trail:fetch_permissions` used to create the Permission
    # rows in the first place: module_name is `controller_path` (e.g.
    # "admin/accounts"), and the action is normalized through
    # `Argus::Trail.config.action_name_mapper` (index/show -> read, new/create
    # -> create, edit/update -> update, destroy -> destroy, anything else kept
    # as-is). A signed-in actor without a role granting that permission gets a
    # 403; a signed-out request also gets a 403 (authenticate first in your
    # own `before_action` if you need a redirect to a login page instead).
    module Authorizable
      extend ActiveSupport::Concern

      included do
        before_action :argus_trail_authorize_permission!
      end

      private

      def argus_trail_authorize_permission!
        actor = send(Argus::Trail.config.current_actor_method)
        return head :forbidden unless actor

        action = Argus::Trail.config.action_name_mapper.call(action_name)
        head :forbidden unless actor.has_permission?(controller_path, action)
      end
    end
  end
end
