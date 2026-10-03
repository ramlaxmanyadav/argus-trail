Argus::Trail.configure do |config|
  # The class name of your app's user/account model — the one that gets
  # `include Argus::Trail::Actor`. No column is added to this model's own
  # table; roles are tracked in the engine's own polymorphic join table, so
  # an actor may hold any number of roles (0..N).
  config.actor_class_name = "User"

  # Rename the engine's Role/Permission/RolePermission model classes — useful
  # if "Role"/"Permission" already collide with another gem or one of your
  # own models. These still back onto the engine's own tables
  # (argus_trail_roles / argus_trail_permissions / argus_trail_role_permissions)
  # — this renames the class, it does not let you point at a pre-existing
  # table with a different schema.
  # config.role_class_name            = "Argus::Trail::Role"
  # config.permission_class_name      = "Argus::Trail::Permission"
  # config.role_permission_class_name = "Argus::Trail::RolePermission"

  # How the engine looks up "who made this change" when writing an audit
  # entry. Defaults to a per-request actor set via:
  #   # in your ApplicationController
  #   before_action { Argus::Trail.current_actor = current_user }
  # Override entirely for jobs/console usage, e.g. `-> { SomeJob.current_actor }`.
  # config.changed_by_resolver = -> { Argus::Trail.current_actor }

  # Gate for who may use the roles/permissions/audit-log admin screens.
  # Left unset, Argus::Trail falls back to Pundit if it's in your Gemfile and
  # a policy is defined (e.g. Argus::Trail::RolePolicy) — otherwise it just
  # requires someone to be signed in, so the admin screens work out of the
  # box with zero policies/config. Tighten either way you like:
  # config.authorize_with = ->(controller, record_or_class) { controller.current_user&.admin? }

  # The method the engine calls on its controllers to get the logged-in actor.
  # config.current_actor_method = :current_user

  # Rows per page on the roles/permissions/audit-log admin screens.
  # config.per_page = 30

  # Render engine screens inside one of your app's own layouts instead of
  # the engine's self-contained Tailwind-CDN layout.
  # config.layout = "application"

  # Extra controller paths `bin/rails argus_trail:fetch_permissions` should
  # skip when scanning your routes to build module-wise permissions (strings
  # or Regexps). The engine's own routes and Rails-internal ones (health
  # check, Active Storage, Action Mailbox/Text) are always skipped.
  # config.permission_scan_excludes = [ "rails/conductor", %r{\Aadmin/sidekiq} ]

  # How a scanned route's Rails action name maps to a permission's `action`
  # column — also used by Argus::Trail::Authorizable. Defaults to collapsing
  # index/show -> read, new/create -> create, edit/update -> update,
  # destroy -> destroy, and keeping anything else (a custom action) as-is.
  # config.action_name_mapper = ->(action) { action.to_s }
end
