# Argus::Trail

A mountable Rails engine that gives any app configurable roles and
permissions — actors can hold any number of roles — plus a unified,
immutable audit log of every role assignment/revocation and every
permission granted/revoked on a role, with ready-made, paginated HTML admin
screens.

See [`docs/INTEGRATION_GUIDE.md`](docs/INTEGRATION_GUIDE.md) for a detailed,
step-by-step walkthrough (including troubleshooting for a couple of easy
integration traps) — this README is the quick-start version.

Stays out of your way on the things it doesn't need to own:
- **No hardcoded role/permission names** — you define whatever `Role`/`Permission` rows you want.
- **No fixed actor class** — works with whatever you call your `User`/`Account` model.
- **No schema change to your actor table** — roles live in the engine's own polymorphic join table, so actors can hold 0..N roles.
- **No required auth library** — works standalone; auto-integrates with [Pundit](https://github.com/varvet/pundit) if it's in your Gemfile.
- **No required pagination library** — auto-integrates with [Kaminari](https://github.com/kaminari/kaminari) if it's in your Gemfile, otherwise falls back to a small built-in pager.

## Installation

```ruby
# Gemfile
gem "argus-trail"
```

```bash
bundle install
bin/rails generate argus:trail:install
bin/rails db:migrate
```

The install generator writes `config/initializers/argus_trail.rb`, creates
the engine's own tables (`argus_trail_roles`, `argus_trail_permissions`,
`argus_trail_role_permissions`, `argus_trail_role_assignments`,
`argus_trail_audit_entries`), and mounts the engine at `/admin/access` in
`config/routes.rb`. There's no migration on your own actor/user table —
`argus_trail_role_assignments` is a polymorphic join table the engine owns
end to end.

It also wires up the two integration points that used to be manual steps:
it adds `include Argus::Trail::Actor` to your actor model (`User` by
default — pass `--actor=YourModel` if it's called something else) and adds
`before_action { Argus::Trail.current_actor = current_user }` to your
`ApplicationController`. Both are idempotent (safe to rerun) and skipped
with an explanatory message if the corresponding file doesn't exist yet.

## Generating module-wise permissions

```bash
bin/rails argus_trail:fetch_permissions
```

Scans your app's routes and creates a `Permission` for every controller
action it finds (skipping the engine's own routes and framework-internal
ones), grouped by `module_name` (the controller, e.g. `"admin/accounts"`)
and `action` (`read`/`create`/`update`/`destroy`, or a custom action name
as-is). It only ever adds permissions — safe to rerun after adding
controllers/actions. `bin/rails argus_trail:fetch_permissions:prune` removes
the ones whose route is gone and that aren't granted to any role.

Visit the mounted engine to create roles and check off which module-wise
permissions (and any permissions you created by hand) each one grants.

## Gating your own controllers

```ruby
class AccountsController < ApplicationController
  include Argus::Trail::Authorizable
end
```

No further code needed — the required permission is derived automatically
from the controller and action (the same `module_name`/`action` pair
`fetch_permissions` generated), using
`Argus::Trail.config.action_name_mapper`. A signed-in actor without a role
granting that permission gets a 403.

## Wiring up your app

**Recording role changes on an actor.** Use `Actor#sync_roles!` (instead of
assigning `role_ids=`/`roles=` directly) so assignments and revocations land
in the audit log, and use `has_permission?` to check a permission by name or
by module + action:

```ruby
user.sync_roles!([ admin_role.id, support_role.id ], changed_by: current_user)

user.has_permission?("manage_billing")        # a plain, manually created permission
user.has_permission?("admin/accounts", :read) # a module-wise permission
```

An actor can hold any number of roles at once; assigning a single role is
just the `new_role_ids.size == 1` case of the same call.

**Authorizing the admin screens.** With neither Pundit nor
`config.authorize_with` configured, the admin screens default to "any
signed-in actor" — they work out of the box with zero policies. Tighten
this with Pundit:

```ruby
class Argus::Trail::RolePolicy < ApplicationPolicy
  def index? = user.admin?
  # ...
end
```

(define the same for `Argus::Trail::PermissionPolicy` and
`Argus::Trail::AuditEntryPolicy`), or with a proc — which always takes
priority over Pundit, so this works even if Pundit happens to also be in
your Gemfile:

```ruby
# config/initializers/argus_trail.rb
Argus::Trail.configure do |config|
  config.authorize_with = ->(controller, record_or_class) { controller.current_user&.admin? }
end
```

See [`docs/INTEGRATION_GUIDE.md`](docs/INTEGRATION_GUIDE.md#8-step-6--authorization)
for a wiring example per authorization gem (Pundit, CanCanCan, Action
Policy, plain proc).

## Recording permission changes on a role

Use `Role#sync_permissions!` (instead of assigning `permission_ids=`
directly) so grants and revokes land in the audit log:

```ruby
role.sync_permissions!(params[:permission_ids], changed_by: current_user)
```

## Customizing the views

```bash
bin/rails generate argus:trail:views
```

Copies every view into `app/views/argus/trail` (and the layout into
`app/views/layouts/argus/trail`) for full override. The shipped layout is
self-contained (Tailwind via CDN) so it renders correctly with zero host
asset-pipeline setup; set `config.layout` to render inside one of your own
layouts instead.

Already running ActiveAdmin and would rather manage roles/permissions there
instead? `Role`/`Permission`/`AuditEntry` are plain ActiveRecord models, so
`ActiveAdmin.register` works directly — see
[`docs/INTEGRATION_GUIDE.md`](docs/INTEGRATION_GUIDE.md#19-optional-registering-with-activeadmin)
for copy-pasteable registrations and the one gotcha to know about (ActiveAdmin's
default checkboxes bypass the audit trail unless you call
`sync_permissions!`/`sync_roles!` explicitly).

## Configuration reference

```ruby
Argus::Trail.configure do |config|
  config.actor_class_name           = "User"   # your user/account model
  config.role_class_name            = "Argus::Trail::Role"       # rename if it collides with another gem/model
  config.permission_class_name      = "Argus::Trail::Permission"
  config.role_permission_class_name = "Argus::Trail::RolePermission"
  config.changed_by_resolver = -> { Argus::Trail.current_actor }
  config.authorize_with      = nil      # see "Authorize the admin screens" above
  config.current_actor_method = :current_user
  config.per_page             = 30
  config.layout                = nil    # e.g. "application"
  config.permission_scan_excludes = []  # extra controller paths for fetch_permissions to skip
  config.action_name_mapper = ->(action) { ... }  # see lib/argus/trail/configuration.rb for the default
end
```

`role_class_name`/`permission_class_name`/`role_permission_class_name` only
rename the classes — they still map to the engine's own
`argus_trail_roles`/`argus_trail_permissions`/`argus_trail_role_permissions`
tables. This is for renaming (e.g. your app already has its own `Role`
model for something unrelated), **not** for pointing the engine at an
existing Role/Permission table with a different schema — see
[`docs/INTEGRATION_GUIDE.md`](docs/INTEGRATION_GUIDE.md#14-configuration-reference)
for the full mapping and caveats.

## Development

```bash
bundle install
bin/rails db:migrate
bin/rails test
```

`test/dummy` is a minimal Rails app (with a `User` model already including
`Argus::Trail::Actor`, and Pundit policies) used to exercise the engine.

## License

MIT.
