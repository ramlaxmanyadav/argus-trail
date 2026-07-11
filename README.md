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

## Wiring up your app

**1. Opt your user model in:**

```ruby
class User < ApplicationRecord
  include Argus::Trail::Actor
end
```

This adds `has_many :roles` (through the engine's join table),
`has_permission?(name)` (true if *any* assigned role has that permission),
and `sync_roles!` — diffs the requested role ids against the ones the actor
currently holds and writes one `AuditEntry` per assignment
(`role_assigned`) or revocation (`role_revoked`):

```ruby
user.sync_roles!([ admin_role.id, support_role.id ], changed_by: current_user)
```

An actor can hold any number of roles at once; assigning a single role is
just the `new_role_ids.size == 1` case of the same call.

**2. Tell the engine who's making changes**, once, in your `ApplicationController`:

```ruby
before_action { Argus::Trail.current_actor = current_user }
```

**3. Authorize the admin screens.** If you have Pundit, define policies —
Argus::Trail uses Pundit's normal lookup, so these are just regular
policies:

```ruby
class Argus::Trail::RolePolicy < ApplicationPolicy
  def index? = user.admin?
  # ...
end
```

Do the same for `Argus::Trail::PermissionPolicy` and
`Argus::Trail::AuditEntryPolicy`. Without Pundit — e.g. if your app uses
CanCanCan, Action Policy, or nothing at all — set `config.authorize_with` to
a proc instead; it always takes priority over Pundit, so this works even if
Pundit happens to also be in your Gemfile:

```ruby
# config/initializers/argus_trail.rb
Argus::Trail.configure do |config|
  config.authorize_with = ->(controller, record_or_class) { controller.current_user&.admin? }
end
```

See [`docs/INTEGRATION_GUIDE.md`](docs/INTEGRATION_GUIDE.md#8-step-6--authorization)
for a wiring example per authorization gem (Pundit, CanCanCan, Action
Policy, plain proc). With neither Pundit nor `authorize_with` configured,
the engine fails closed and raises an actionable error rather than silently
allowing access.

## Recording role changes on an actor

Use `Actor#sync_roles!` (instead of assigning `role_ids=`/`roles=` directly)
so assignments and revocations land in the audit log:

```ruby
user.sync_roles!(params[:role_ids], changed_by: current_user)
```

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
