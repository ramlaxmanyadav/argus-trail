# Argus::Trail

A mountable Rails engine that gives any app configurable roles and
permissions, plus a unified, immutable audit log of every role reassignment
and every permission granted/revoked on a role — with ready-made, paginated
HTML admin screens.

See [`docs/INTEGRATION_GUIDE.md`](docs/INTEGRATION_GUIDE.md) for a detailed,
step-by-step walkthrough (including troubleshooting for a couple of easy
integration traps) — this README is the quick-start version.

Stays out of your way on the things it doesn't need to own:
- **No hardcoded role/permission names** — you define whatever `Role`/`Permission` rows you want.
- **No fixed actor class** — works with whatever you call your `User`/`Account` model.
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
`argus_trail_role_permissions`, `argus_trail_audit_entries`), adds a
`role_id` column to your users table (configurable via
`--actor-table=accounts`), and mounts the engine at `/admin/access` in
`config/routes.rb`.

## Wiring up your app

**1. Opt your user model in:**

```ruby
class User < ApplicationRecord
  include Argus::Trail::Actor
end
```

This adds `belongs_to :role`, `has_permission?(name)`, and writes an audit
entry automatically whenever a user's `role` changes.

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
`Argus::Trail::AuditEntryPolicy`. Without Pundit, set a proc instead:

```ruby
# config/initializers/argus_trail.rb
Argus::Trail.configure do |config|
  config.authorize_with = ->(controller, record_or_class) { controller.current_user&.admin? }
end
```

With neither configured, the engine fails closed and raises an actionable
error rather than silently allowing access.

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

## Configuration reference

```ruby
Argus::Trail.configure do |config|
  config.actor_class_name    = "User"   # your user/account model
  config.changed_by_resolver = -> { Argus::Trail.current_actor }
  config.authorize_with      = nil      # see "Authorize the admin screens" above
  config.current_actor_method = :current_user
  config.per_page             = 30
  config.layout                = nil    # e.g. "application"
end
```

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
