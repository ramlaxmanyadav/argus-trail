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
      # Pundit is bundled *and* a policy is actually defined for this record
      # (e.g. Argus::Trail::RolePolicy), delegate to it; otherwise fall back to
      # the plug-and-play default below so the admin screens work out of the
      # box with no policies and no config.
      def authorize_access!(record_or_class)
        handler = Argus::Trail.config.authorize_with
        return handler.call(self, record_or_class) if handler
        return authorize(record_or_class) if defined?(Pundit) && pundit_policy_defined?(record_or_class)

        # No Pundit policy and no authorize_with configured — just require a
        # signed-in actor. Define a policy or set config.authorize_with to
        # tighten this further (e.g. restrict to admins only).
        head :forbidden unless current_actor
      end

      # Scope a relation down to what the current actor may see. Only Pundit's
      # policy_scope narrows results; a custom authorize_with is a yes/no gate,
      # not a scope, so it leaves the relation as-is — same for the
      # plug-and-play default.
      def authorized_scope(scope_class)
        return policy_scope(scope_class) if Argus::Trail.config.authorize_with.nil? && defined?(Pundit) && pundit_policy_defined?(scope_class)
        scope_class.all
      end

      def pundit_policy_defined?(record_or_class)
        Pundit::PolicyFinder.new(record_or_class).policy.present?
      rescue NameError
        false
      end
    end
  end
end
