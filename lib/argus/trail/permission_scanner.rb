module Argus
  module Trail
    # Scans the host app's routes to build the (module_name, action) pairs
    # that back module-wise permissions — the same data `bin/rails
    # argus_trail:fetch_permissions` syncs into Permission rows, and that
    # Argus::Trail::Authorizable checks a signed-in actor against.
    #
    # `module_name` is a route's controller path exactly as Rails reports it
    # (e.g. "admin/accounts", "sessions") — the same string
    # `ActionController::Metal#controller_path` returns at runtime, so a
    # scanned permission always lines up with the controller it came from.
    class PermissionScanner
      DEFAULT_EXCLUDES = [
        %r{\Aargus/trail/},
        %r{\Arails/},
        %r{\Aactive_storage/},
        %r{\Aaction_mailbox/},
        %r{\Aaction_text/},
        "rails/health_check"
      ].freeze

      def self.scan
        new.scan
      end

      # Array of unique [module_name, action] pairs across every routed
      # controller action, actions already normalized via
      # `Argus::Trail.config.action_name_mapper`.
      def scan
        Rails.application.eager_load!

        routes.filter_map { |route| build_pair(route) }.uniq
      end

      private

      def routes
        Rails.application.routes.routes
      end

      def build_pair(route)
        controller = route.defaults[:controller]
        action = route.defaults[:action]
        return if controller.blank? || action.blank?
        return if excluded?(controller)

        [ controller, Argus::Trail.config.action_name_mapper.call(action) ]
      end

      def excluded?(controller)
        excludes.any? { |pattern| pattern.is_a?(Regexp) ? pattern.match?(controller) : pattern.to_s == controller }
      end

      def excludes
        DEFAULT_EXCLUDES + Array(Argus::Trail.config.permission_scan_excludes)
      end
    end
  end
end
