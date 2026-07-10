Argus::Trail.configure do |config|
  # The class name of your app's user/account model — the one that gets
  # `include Argus::Trail::Actor` and a `role_id` column.
  config.actor_class_name = "User"

  # How the engine looks up "who made this change" when writing an audit
  # entry. Defaults to a per-request actor set via:
  #   # in your ApplicationController
  #   before_action { Argus::Trail.current_actor = current_user }
  # Override entirely for jobs/console usage, e.g. `-> { SomeJob.current_actor }`.
  # config.changed_by_resolver = -> { Argus::Trail.current_actor }

  # Gate for who may use the roles/permissions/audit-log admin screens.
  # Left unset, Argus::Trail falls back to Pundit if it's in your Gemfile
  # (define Argus::Trail::RolePolicy / PermissionPolicy / AuditEntryPolicy)
  # — otherwise it raises until you set one of the two.
  # config.authorize_with = ->(controller, record_or_class) { controller.current_user&.admin? }

  # The method the engine calls on its controllers to get the logged-in actor.
  # config.current_actor_method = :current_user

  # Rows per page on the roles/permissions/audit-log admin screens.
  # config.per_page = 30

  # Render engine screens inside one of your app's own layouts instead of
  # the engine's self-contained Tailwind-CDN layout.
  # config.layout = "application"
end
