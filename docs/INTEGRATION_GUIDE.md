# Argus::Trail Integration Guide

This is the detailed, step-by-step companion to the README's quick start.
Every step below was actually run against a fresh Rails 8 app
(`argus_trail_demo`) during development — the code samples are copied from
that working integration, not hypothetical.

## Contents

1. [What you get](#1-what-you-get)
2. [Requirements](#2-requirements)
3. [Step 1 — Add the gem](#3-step-1--add-the-gem)
4. [Step 2 — Run the install generator](#4-step-2--run-the-install-generator)
5. [Step 3 — Migrate](#5-step-3--migrate)
6. [Step 4 — Opt your actor model in](#6-step-4--opt-your-actor-model-in)
7. [Step 5 — Tell the engine who's acting](#7-step-5--tell-the-engine-whos-acting)
8. [Step 6 — Authorization](#8-step-6--authorization)
9. [Step 7 — Pagination](#9-step-7--pagination)
10. [Step 8 — Mounting & routes](#10-step-8--mounting--routes)
11. [Step 9 — Customizing views](#11-step-9--customizing-views)
12. [Step 10 — Recording permission changes on a role](#12-step-10--recording-permission-changes-on-a-role)
13. [Configuration reference](#13-configuration-reference)
14. [Gotchas & troubleshooting](#14-gotchas--troubleshooting)
15. [Verifying your integration](#15-verifying-your-integration)
16. [Full worked example](#16-full-worked-example)
17. [Uninstalling](#17-uninstalling)

---

## 1. What you get

- `Argus::Trail::Role` / `Argus::Trail::Permission` — plain models, no
  hardcoded name lists, `has_many` join through `Argus::Trail::RolePermission`.
- `Argus::Trail::AuditEntry` — one immutable, append-only table logging
  **both** role reassignments and permission grants/revokes on a role.
- A mounted engine with full Tailwind-styled, paginated HTML CRUD for roles,
  permissions, and the audit log — no view code to write.
- Zero hard dependency on your auth or pagination stack.

## 2. Requirements

- Rails >= 7.1 (tested on 8.1)
- A user/account model (any name, any table name)
- Optional: [Pundit](https://github.com/varvet/pundit) for authorization,
  [Kaminari](https://github.com/kaminari/kaminari) for pagination. Neither is
  required — see [Step 6](#8-step-6--authorization) and
  [Step 7](#9-step-7--pagination).

## 3. Step 1 — Add the gem

```ruby
# Gemfile
gem "argus-trail"                      # once published
# or, while developing locally:
gem "argus-trail", path: "../argus-trail"
```

```bash
bundle install
```

## 4. Step 2 — Run the install generator

```bash
bin/rails generate argus:trail:install
```

Note the **colon-separated** namespace (`argus:trail:install`, not
`argus_trail:install`) — it mirrors the nested `Argus::Trail` Ruby module,
the same convention Rails itself uses for gems like `rails-html-sanitizer`
(`Rails::Html::Sanitizer`).

This creates:

```
create  config/initializers/argus_trail.rb
create  db/migrate/<timestamp>_create_argus_trail_tables.rb
create  db/migrate/<timestamp>_add_role_to_users.rb
 route  mount Argus::Trail::Engine => "/admin/access"
```

If your user table isn't literally `users`, pass it explicitly so the second
migration targets the right table:

```bash
bin/rails generate argus:trail:install --actor-table=accounts
```

The route-mounting step is idempotent — re-running `install` won't add a
second `mount` line if one already exists.

## 5. Step 3 — Migrate

```bash
bin/rails db:migrate
```

Creates four engine-owned tables, all prefixed to avoid any collision with
your app's own tables: `argus_trail_roles`, `argus_trail_permissions`,
`argus_trail_role_permissions`, `argus_trail_audit_entries`. Plus a nullable
`role_id` column + FK on your actor table.

## 6. Step 4 — Opt your actor model in

```ruby
# app/models/user.rb
class User < ApplicationRecord
  include Argus::Trail::Actor

  # optional, but recommended — used anywhere the engine needs to show a
  # human-readable label for a user (audit log "Subject"/"Changed By"
  # columns, role show page). Falls back to #name, then #email, then "#<id>".
  def argus_trail_display_name
    name.presence || email
  end
end
```

This one `include` adds:
- `belongs_to :role, class_name: "Argus::Trail::Role", optional: true`
- `has_permission?(permission_name)` — delegates to the assigned role
- An `after_update` callback that writes an `AuditEntry` automatically
  whenever `role_id` changes (including to/from `nil`)

This works alongside anything else already on your model — in the sample
app, `User` also has `has_secure_password` and its own validations; the
concern doesn't care.

## 7. Step 5 — Tell the engine who's acting

The engine needs to know who made each change so it can populate
`AuditEntry#changed_by`. Wire it once, per-request, in your
`ApplicationController`:

```ruby
class ApplicationController < ActionController::Base
  before_action { Argus::Trail.current_actor = current_user }
end
```

This is backed by the engine's own `ActiveSupport::CurrentAttributes` class,
so it's automatically request-isolated (like `Current.user` patterns) — you
don't need to reset it yourself between requests.

**Outside a request** (rake tasks, console, background jobs), set it
manually before touching anything role/permission-related:

```ruby
Argus::Trail.current_actor = some_system_user   # or nil for "System"
SomeUser.update!(role: new_role)
```

Or override how it's resolved entirely, e.g. to read a job's own actor
tracking instead of the engine's `Current`:

```ruby
# config/initializers/argus_trail.rb
Argus::Trail.configure do |config|
  config.changed_by_resolver = -> { SomeJob.current_actor }
end
```

## 8. Step 6 — Authorization

Argus::Trail never assumes an auth library. Its base controller resolves
authorization in this order, on every action:

1. `config.authorize_with` proc, if you set one — always wins.
2. Pundit, if `defined?(Pundit)` — uses Pundit's **normal namespaced lookup**,
   so you just write real policies at the paths Pundit already expects.
3. Neither configured → raises `Argus::Trail::Configuration::MissingAuthorization`
   with an actionable message. **Fails closed**, never silently open.

### Option A — Pundit

```ruby
# app/policies/argus/trail/role_policy.rb
module Argus
  module Trail
    class RolePolicy < ApplicationPolicy
      def index? = user.admin?
      def show? = user.admin?
      def create? = user.admin?
      def new? = create?
      def update? = user.admin?
      def edit? = update?
      def destroy? = user.admin?
    end
  end
end
```

Do the same for `Argus::Trail::PermissionPolicy` and
`Argus::Trail::AuditEntryPolicy` (or just subclass `ApplicationPolicy` with
an empty body if it already defaults every action to admin-only, as in the
demo app). Pundit resolves `Argus::Trail::Role` → `Argus::Trail::RolePolicy`
automatically — no configuration needed, it's the same namespaced-record
convention Pundit already uses everywhere else.

**Important:** if your `ApplicationController` has (or will have) a
`rescue_from Pundit::NotAuthorizedError`, see the
[`main_app.` gotcha](#gotcha-1-infinite-redirect-loop-in-a-shared-rescue_from)
below before wiring it up — it's an easy trap.

### Option B — no Pundit, a plain proc

```ruby
# config/initializers/argus_trail.rb
Argus::Trail.configure do |config|
  config.authorize_with = ->(controller, record_or_class) do
    controller.current_user&.admin? or
      raise Argus::Trail::Configuration::MissingAuthorization if controller.current_user.nil?
  end
end
```

Simpler version, if you're fine with just returning a boolean (the engine
doesn't require raising — a falsy return simply won't stop the action by
itself, so pair it with your own `before_action` if you want a hard deny; in
practice most hosts pull in Pundit for this reason):

```ruby
config.authorize_with = ->(controller, record_or_class) { controller.current_user&.admin? }
```

## 9. Step 7 — Pagination

Nothing to configure. The audit log (and any future paginated view) calls
`Argus::Trail::Pagination.paginate(relation, page:, per:)`, which:

- Uses Kaminari's `.page(page).per(per)` if `defined?(Kaminari)` — real
  Kaminari pager UI renders automatically.
- Otherwise falls back to a small built-in `SimplePage` + a bundled partial
  with prev/next links — no extra gem required.

Both paths were verified against the same seeded dataset during development;
behavior is identical from the user's perspective either way.

## 10. Step 8 — Mounting & routes

Default mount point (set by the install generator):

```ruby
# config/routes.rb
mount Argus::Trail::Engine => "/admin/access"
```

Change the path by editing that line directly — there's no separate config
option for it, it's a normal engine mount. If you didn't run the install
generator (e.g. you're mounting manually), add the same line yourself; the
route names inside the engine (`roles_path`, `permission_path`, etc.) work
either way since the engine is `isolate_namespace`d.

## 11. Step 9 — Customizing views

```bash
bin/rails generate argus:trail:views
```

Copies every view into `app/views/argus/trail/**` and the layout into
`app/views/layouts/argus/trail/application.html.erb`, verbatim — Rails will
now prefer your copies over the engine's own. Common reasons to do this:

- Swap the Tailwind-CDN layout for your own compiled CSS / your app's shared layout
- Add columns to the roles/permissions tables (e.g. show a "last updated" timestamp)
- Restyle to match your design system

If you'd rather keep the engine's own layout but render inside one of your
app's layouts, skip the views generator and just set:

```ruby
config.layout = "application"   # looks up app/views/layouts/application.html.erb
```

## 12. Step 10 — Recording permission changes on a role

Always go through `Role#sync_permissions!`, not `role.permission_ids=`
directly — this is what actually generates the audit trail for permission
grants/revokes (`role.update` alone only covers `name`/`description`):

```ruby
# in a controller — the engine's own RolesController#create/#update do exactly this
role.sync_permissions!(params[:permission_ids], changed_by: current_user)

# or anywhere else in your app
role.sync_permissions!([permission_a.id, permission_b.id], changed_by: some_admin)
```

It diffs the requested id list against the role's current permissions and
writes one `AuditEntry` per addition (`permission_granted`) and per removal
(`permission_revoked`) — not a single generic "role updated" row.

## 13. Configuration reference

```ruby
# config/initializers/argus_trail.rb
Argus::Trail.configure do |config|
  config.actor_class_name     = "User"     # your user/account model's class name
  config.changed_by_resolver  = -> { Argus::Trail.current_actor }
  config.authorize_with       = nil        # nil => Pundit if present, else raises
  config.current_actor_method = :current_user
  config.per_page              = 30
  config.layout                 = nil       # e.g. "application"
end
```

| Option | Default | Effect |
|---|---|---|
| `actor_class_name` | `"User"` | Resolved lazily (as a string, constantized on first use) so it's safe even if the class isn't loaded yet at boot. |
| `changed_by_resolver` | reads `Argus::Trail.current_actor` | Called with no args every time an `AuditEntry` is written, to populate `changed_by`. |
| `authorize_with` | `nil` | See [Step 6](#8-step-6--authorization). |
| `current_actor_method` | `:current_user` | The method name the engine's base controller calls on itself (inherited from your `ApplicationController`) to find the logged-in actor. |
| `per_page` | `30` | Rows per page on all three admin screens. |
| `layout` | `nil` | Set to render engine pages inside one of your app's own layouts instead of the engine's self-contained one. |

## 14. Gotchas & troubleshooting

#### Gotcha 1: infinite redirect loop in a shared `rescue_from`

If your `ApplicationController` (which `Argus::Trail::ApplicationController`
inherits from) has:

```ruby
rescue_from Pundit::NotAuthorizedError, with: :deny_access

def deny_access
  redirect_to root_path, alert: "Not authorized"   # BUG when raised inside the engine
end
```

...this loops forever when the exception is raised from inside an
**engine** controller. Isolated engines (`isolate_namespace`) scope bare
route helpers to themselves — inside `Argus::Trail::RolesController`,
`root_path` resolves to the *engine's own* root (`/admin/access/`, i.e. right
back to the page that was just denied), not your app's root. Fix:

```ruby
def deny_access
  redirect_to main_app.root_path, alert: "Not authorized"
end
```

This bit us in exactly this form while building the demo app — a viewer-role
user hitting `/admin/access/roles` 500'd with "Maximum (50) redirects
followed" until this was fixed.

#### Gotcha 2: no `rescue_from` at all → raw 500 on denial

Without any `rescue_from Pundit::NotAuthorizedError`, a denied user gets a
plain 500 (visible in logs as `Pundit::NotAuthorizedError (not allowed to
Argus::Trail::RolePolicy#index? ...)`), not a friendly redirect. This is
normal Pundit behavior, not an engine bug — add the `rescue_from` (with the
`main_app.` fix above) in your own `ApplicationController` as you would for
any other Pundit-protected controller.

#### Gotcha 3: `--actor-table` mismatch

If you run `install` with the default `--actor-table=users` but your actual
table is `accounts`, the second migration (`add_role_to_users.rb`) will fail
against a nonexistent table. Either re-run with `--actor-table=accounts`
before migrating, or hand-edit the generated migration's `add_reference`
call before running `db:migrate`.

#### Gotcha 4: `MissingAuthorization` on every request

If you see `Argus::Trail could not determine how to authorize access...`,
neither Pundit is in your Gemfile nor `config.authorize_with` is set. This
is deliberate fail-closed behavior — set one of the two (see
[Step 6](#8-step-6--authorization)).

#### Gotcha 5: audit entries show "System" as Changed By

This means `Argus::Trail.current_actor` was `nil` at write time — usually
because the change happened outside a request (console, `db:seed`, a rake
task) without setting it first. Set it manually (see
[Step 5](#7-step-5--tell-the-engine-whos-acting)) if you want a real actor
attributed, or leave it as "System" if that's accurate (e.g. seed data).

## 15. Verifying your integration

A quick checklist, in the order we actually ran it against the demo app:

```bash
bin/rails generate argus:trail:install
bin/rails db:migrate
bin/rails runner '
  role = Argus::Trail::Role.create!(name: "admin", description: "test")
  perm = Argus::Trail::Permission.create!(name: "test_perm", description: "test")
  role.sync_permissions!([perm.id])
  user = User.first || User.create!(email: "test@example.com", password: "password123")
  Argus::Trail.current_actor = user
  user.update!(role: role)
  puts Argus::Trail::AuditEntry.count   # should be 2: one permission_granted, one role_assigned
'
bin/rails server
# visit /admin/access/roles, /admin/access/permissions, /admin/access/audit_entries
# as an authorized user, and confirm a non-authorized user is denied
```

## 16. Full worked example

The `argus_trail_demo` app built alongside this gem does all of the above
for real. Its key files, in case you want to copy the pattern directly:

- `app/models/user.rb` — `has_secure_password` + `include Argus::Trail::Actor` + `argus_trail_display_name`
- `app/controllers/application_controller.rb` — session-based `current_user`, the `Argus::Trail.current_actor` wiring, and the `rescue_from` with the `main_app.` fix
- `app/policies/application_policy.rb` + `app/policies/argus/trail/{role,permission,audit_entry}_policy.rb` — admin-only Pundit policies
- `db/seeds.rb` — creates roles/permissions via `sync_permissions!` and users via `find_or_initialize_by`, demonstrating the audit trail being populated from seed data

## 17. Uninstalling

There's no `uninstall` generator (the gem intentionally never touches your
`user.rb` automatically, so there's nothing scripted to reverse there
either). To remove:

1. Remove the `include Argus::Trail::Actor` line from your actor model.
2. Remove the `mount Argus::Trail::Engine => ...` line from `config/routes.rb`.
3. Write and run a migration dropping the four `argus_trail_*` tables and
   the `role_id` column/FK you added to your actor table.
4. Remove `config/initializers/argus_trail.rb` and the gem from your Gemfile.
