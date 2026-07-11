module Argus
  module Trail
    class Configuration
      class MissingAuthorization < StandardError
        def message
          "Argus::Trail could not determine how to authorize access to its admin screens. " \
            "Either add Pundit to your Gemfile with Argus::Trail::Role/Permission policies, " \
            "or set `config.authorize_with` in config/initializers/argus_trail.rb " \
            "(e.g. `config.authorize_with = ->(controller, record) { controller.current_user&.admin? }`)."
        end
      end

      attr_accessor :actor_class_name, :role_class_name, :permission_class_name,
                    :role_permission_class_name, :changed_by_resolver, :authorize_with,
                    :current_actor_method, :per_page, :layout

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
