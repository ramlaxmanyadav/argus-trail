module Argus
  module Trail
    # Inherits from the *host* app's ApplicationController (not
    # ActionController::Base) — the standard mountable-engine trick that gets
    # current_user/session/CSRF/flash/Devise helpers/layout for free.
    class ApplicationController < ::ApplicationController
      include Pundit::Authorization if defined?(Pundit)

      layout -> { Argus::Trail.config.layout || "argus/trail/application" }

      helper_method :current_actor

      private

      def current_actor
        send(Argus::Trail.config.current_actor_method)
      end

      # Call with a record (show/edit/update/destroy) or a class (index/new/create).
      # Resolution order: an explicitly configured proc always wins; otherwise, if
      # Pundit is bundled, delegate to it (host must define policies, e.g.
      # Argus::Trail::RolePolicy — same lookup Pundit already does for any
      # namespaced record); otherwise fail closed with an actionable error.
      def authorize_access!(record_or_class)
        handler = Argus::Trail.config.authorize_with
        return handler.call(self, record_or_class) if handler
        return authorize(record_or_class) if defined?(Pundit)

        raise Argus::Trail::Configuration::MissingAuthorization
      end

      # Scope a relation down to what the current actor may see. Only Pundit's
      # policy_scope narrows results; a custom authorize_with is a yes/no gate,
      # not a scope, so it leaves the relation as-is.
      def authorized_scope(scope_class)
        return authorized_scope_via_pundit(scope_class) if Argus::Trail.config.authorize_with.nil? && defined?(Pundit)
        scope_class.all
      end

      def authorized_scope_via_pundit(scope_class)
        policy_scope(scope_class)
      end
    end
  end
end
