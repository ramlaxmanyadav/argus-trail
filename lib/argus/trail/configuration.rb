module Argus
  module Trail
    class Configuration
      attr_accessor :actor_class_name, :role_class_name, :permission_class_name,
                    :role_permission_class_name, :changed_by_resolver, :authorize_with,
                    :current_actor_method, :per_page, :layout,
                    :permission_scan_excludes, :action_name_mapper

      def initialize
        @actor_class_name           = "User"
        @role_class_name            = "Argus::Trail::Role"
        @permission_class_name      = "Argus::Trail::Permission"
        @role_permission_class_name = "Argus::Trail::RolePermission"
        @changed_by_resolver = -> { Argus::Trail::Current.actor }
        @authorize_with      = nil
        @current_actor_method = :current_user
        @per_page            = 30
        @layout              = nil

        # Used by `bin/rails argus_trail:fetch_permissions` when scanning your
        # app's routes to build module-wise (controller x action) permissions.
        # Extra controller paths (strings or Regexps) to skip, on top of the
        # engine's own routes and framework-internal ones (Rails health check,
        # Active Storage, Action Mailbox/Text), which are always excluded.
        @permission_scan_excludes = []

        # How a route's Rails action name maps to the permission's `action`
        # column. Default collapses the standard 7 REST actions down to the
        # 4 CRUD-ish verbs the admin UI groups checkboxes by; anything else
        # (a custom member/collection action) is kept as-is.
        @action_name_mapper = lambda do |action|
          case action.to_s
          when "index", "show" then "read"
          when "new", "create" then "create"
          when "edit", "update" then "update"
          when "destroy" then "destroy"
          else action.to_s
          end
        end
      end

      def actor_class
        actor_class_name.to_s.constantize
      end

      def role_class
        role_class_name.to_s.constantize
      end

      def permission_class
        permission_class_name.to_s.constantize
      end

      def role_permission_class
        role_permission_class_name.to_s.constantize
      end
    end
  end
end
