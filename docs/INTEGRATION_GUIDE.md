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
12. [Step 10 — Recording role changes on an actor](#12-step-10--recording-role-changes-on-an-actor)
13. [Step 11 — Recording permission changes on a role](#13-step-11--recording-permission-changes-on-a-role)
14. [Configuration reference](#14-configuration-reference)
    - 14a. [Using your own Role/Permission class names](#14a-using-your-own-rolepermission-class-names)
15. [Gotchas & troubleshooting](#15-gotchas--troubleshooting)
16. [Verifying your integration](#16-verifying-your-integration)
17. [Full worked example](#17-full-worked-example)
18. [Uninstalling](#18-uninstalling)
19. [Optional: registering with ActiveAdmin](#19-optional-registering-with-activeadmin)

---

## 1. What you get

- `Argus::Trail::Role` / `Argus::Trail::Permission` — plain models, no
  hardcoded name lists, `has_many` join through `Argus::Trail::RolePermission`.
- **Actors can hold any number of roles** — the actor↔role relationship is a
  polymorphic many-to-many join (`Argus::Trail::RoleAssignment`), not a single
  FK column, so assigning multiple roles to one user is a first-class case,
  not a workaround.
- `Argus::Trail::AuditEntry` — one immutable, append-only table logging
  **both** role assignments/revocations on an actor and permission
  grants/revokes on a role.
- A mounted engine with full Tailwind-styled, paginated HTML CRUD for roles,
  permissions, and the audit log — no view code to write.
- Zero hard dependency on your auth or pagination stack.

## 2. Requirements

- Rails >= 6.1 (tested on 8.1; the `AuditEntry#metadata` column uses the
  `:json` attribute type rather than `serialize ..., coder:`, since the
  latter is a 7.1+-only API)
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
 route  mount Argus::Trail::Engine => "/admin/access"
```

There's no second migration for your own actor/user table, and no
`--actor-table` option — the actor↔role relationship lives entirely in the
engine's own polymorphic `argus_trail_role_assignments` table, so any actor
class works without a schema change on its own table.

The route-mounting step is idempotent — re-running `install` won't add a
second `mount` line if one already exists.

## 5. Step 3 — Migrate

```bash
bin/rails db:migrate
```

Creates five engine-owned tables, all prefixed to avoid any collision with
your app's own tables: `argus_trail_roles`, `argus_trail_permissions`,
`argus_trail_role_permissions`, `argus_trail_role_assignments`,
`argus_trail_audit_entries`. Nothing is added to your actor table.

`argus_trail_role_assignments` is the actor↔role join: `actor_type`/`actor_id`
(polymorphic) + `role_id`, unique on the combination — one row per role an
actor holds, so an actor can have zero, one, or many rows here.

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
- `has_many :roles` (through the engine's `argus_trail_role_assignments` join) — an actor can hold any number of roles
- `has_permission?(permission_name)` — true if **any** of the actor's assigned roles has that permission
- `sync_roles!(new_role_ids, changed_by:)` — diffs the requested role ids against the ones currently assigned and writes one `AuditEntry` per addition (`role_assigned`) or removal (`role_revoked`)

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
some_user.sync_roles!([ new_role.id ])
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

Which option to use, by authorization gem:

| Your auth stack | Option | Notes |
|---|---|---|
| Pundit | [A](#option-a--pundit) | Zero config — auto-detected via `defined?(Pundit)`. |
| Nothing / a hand-rolled check | [B](#option-b--no-pundit-a-plain-proc) | Simplest possible integration. |
| CanCanCan | [C](#option-c--cancancan) | Not auto-detected (only Pundit is) — always goes through `authorize_with`. |
| Action Policy / anything else | [D](#option-d--action-policy-or-any-other-library) | Same `authorize_with` shape as CanCanCan. |
| Pundit *and* CanCanCan both in the Gemfile | C or D's proc | `authorize_with` always wins over the Pundit auto-detection, so set it explicitly to whichever library should govern these screens. |

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

If you've renamed the model via `config.role_class_name` (see
[§14a](#14a-using-your-own-rolepermission-class-names)), Pundit's lookup
follows the *renamed* class, not `Argus::Trail::Role` — e.g.
`role_class_name = "Argus::Trail::AccessRole"` needs
`Argus::Trail::AccessRolePolicy`, not `RolePolicy`.

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

### Option C — CanCanCan

`authorize_with` is checked *before* Pundit ([resolution order](#8-step-6--authorization)
above), so this works whether or not Pundit is also in your Gemfile. Wire it
to CanCanCan's `Ability`/`can?`:

```ruby
# config/initializers/argus_trail.rb
Argus::Trail.configure do |config|
  config.authorize_with = ->(controller, record_or_class) do
    controller.current_ability.authorize!(:manage, record_or_class)
  end
end
```

`record_or_class` is exactly what CanCanCan expects — a class on
`index`/`new`/`create` (e.g. `Argus::Trail::Role`), an instance on
`show`/`edit`/`update`/`destroy`. `authorize!` raises
`CanCan::AccessDenied` on denial, so add the usual
`rescue_from CanCan::AccessDenied` in your `ApplicationController` (watch
for the [`main_app.` gotcha](#gotcha-1-infinite-redirect-loop-in-a-shared-rescue_from)
below — it applies to any raising authorization library, not just Pundit).
If you'd rather fail soft, use `can?` instead of `authorize!` and handle the
`false` case with your own `before_action`, same as Option B.

### Option D — Action Policy, or any other library

Same shape — `authorize_with` just needs to return truthy/raise. For Action
Policy:

```ruby
config.authorize_with = ->(controller, record_or_class) do
  controller.authorize!(record_or_class, to: :manage?)
end
```

Anything that exposes a `controller`-callable check works here; the engine
never inspects which library is behind the proc.

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

## 12. Step 10 — Recording role changes on an actor

Always go through `Actor#sync_roles!`, not `actor.role_ids=`/`actor.roles=`
directly — this is what actually generates the audit trail:

```ruby
# anywhere in your app — e.g. an admin screen for assigning roles to a user
user.sync_roles!(params[:role_ids], changed_by: current_user)

# assigning a single role is just a one-element list
user.sync_roles!([ admin_role.id ], changed_by: current_user)

# an actor can hold several roles at once
user.sync_roles!([ admin_role.id, support_role.id ], changed_by: current_user)

# clearing all roles
user.sync_roles!([], changed_by: current_user)
```

It diffs the requested id list against the actor's current roles and writes
one `AuditEntry` per addition (`role_assigned`) and per removal
(`role_revoked`) — not a single generic "role updated" row, and not tied to
a before/after pair the way a single `role_id` column would be. Querying
"who currently holds role X" is `role.actors`; "what roles does this actor
hold" is `actor.roles`.

## 13. Step 11 — Recording permission changes on a role

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

## 14. Configuration reference

```ruby
# config/initializers/argus_trail.rb
Argus::Trail.configure do |config|
  config.actor_class_name           = "User"     # your user/account model's class name
  config.role_class_name            = "Argus::Trail::Role"
  config.permission_class_name      = "Argus::Trail::Permission"
  config.role_permission_class_name = "Argus::Trail::RolePermission"
  config.changed_by_resolver  = -> { Argus::Trail.current_actor }
  config.authorize_with       = nil        # nil => Pundit if present, else raises
  config.current_actor_method = :current_user
  config.per_page              = 30
  config.layout                 = nil       # e.g. "application"
end
```

| Option | Default | Effect |
|---|---|---|
| `actor_class_name` | `"User"` | Resolved lazily (as a string, constantized on first use) so it's safe even if the class isn't loaded yet at boot. Only used as the concrete type for `Role#actors` (a `has_many :through` needs one type to instantiate) — the underlying `argus_trail_role_assignments` join itself is polymorphic. |
| `role_class_name` | `"Argus::Trail::Role"` | Class used for role records — see [§14a](#14a-using-your-own-rolepermission-class-names). |
| `permission_class_name` | `"Argus::Trail::Permission"` | Class used for permission records — see [§14a](#14a-using-your-own-rolepermission-class-names). |
| `role_permission_class_name` | `"Argus::Trail::RolePermission"` | Class used for the role↔permission join model — see [§14a](#14a-using-your-own-rolepermission-class-names). |
| `changed_by_resolver` | reads `Argus::Trail.current_actor` | Called with no args every time an `AuditEntry` is written, to populate `changed_by`. |
| `authorize_with` | `nil` | See [Step 6](#8-step-6--authorization). |
| `current_actor_method` | `:current_user` | The method name the engine's base controller calls on itself (inherited from your `ApplicationController`) to find the logged-in actor. |
| `per_page` | `30` | Rows per page on all three admin screens. |
| `layout` | `nil` | Set to render engine pages inside one of your app's own layouts instead of the engine's self-contained one. |

## 14a. Using your own Role/Permission class names

All three (`role_class_name`, `permission_class_name`,
`role_permission_class_name`) default to the engine's own
`Argus::Trail::Role` / `Permission` / `RolePermission`, and every internal
reference — the `Actor` concern's `has_many :roles`, `Role#sync_permissions!`,
`Actor#sync_roles!`, `AuditEntry#role`/`#permission`, and the roles/permissions
controllers — resolves the class through config instead of hardcoding the
constant, so overriding one of these settings changes it everywhere
consistently.

**What this is for:** renaming, not swapping in an unrelated model. Set
these when the bare names `Role`/`Permission` would collide with something
else in your app (another gem that defines a top-level `Role`, or your own
domain model that isn't this kind of role) and you'd rather the engine's
classes live under a different name:

```ruby
# config/initializers/argus_trail.rb
Argus::Trail.configure do |config|
  config.role_class_name       = "Argus::Trail::AccessRole"
  config.permission_class_name = "Argus::Trail::AccessPermission"
end
```

```ruby
# app/models/argus/trail/access_role.rb — still backed by argus_trail_roles
module Argus
  module Trail
    class AccessRole < Role
    end
  end
end
```

**What this is *not* for:** pointing the engine at a Role/Permission table
your app already has, with its own schema (e.g. an existing `roles` table
from Rolify, `acts_as_authorization`, or a hand-rolled RBAC system).
`role_class_name`/`permission_class_name` only rename which Ruby class
wraps the data — the underlying tables are still the ones the install
generator's migration created (`argus_trail_roles`,
`argus_trail_permissions`, `argus_trail_role_permissions`,
`argus_trail_role_assignments`), with the exact columns/associations the
engine's controllers and views expect (`name`, `description`, the
`role_permissions`/`role_assignments` joins, `sync_permissions!`,
`sync_roles!`, etc.). There's no supported way to back these classes with a
differently shaped, pre-existing table — that would require the engine's
models, migrations, and every view to be rewritten against your schema,
which is out of scope for a config setting. If you already have your own
role/permission system and only want Argus::Trail's audit log and admin
screens for a *separate* concept, run the two side by side under different
names rather than trying to merge them.

## 15. Gotchas & troubleshooting

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

#### Gotcha 3: `has_permission?` reflects the union of all assigned roles

Since an actor can hold multiple roles, `has_permission?("delete_users")` is
true if **any** assigned role grants it — there's no built-in way to ask
"does this specific role grant this permission" from the actor side. Use
`role.permissions.exists?(name: "delete_users")` on a specific `Role` for
that instead.

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

## 16. Verifying your integration

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
  user.sync_roles!([role.id])
  puts Argus::Trail::AuditEntry.count   # should be 2: one permission_granted, one role_assigned
  puts user.has_permission?("test_perm")   # true
'
bin/rails server
# visit /admin/access/roles, /admin/access/permissions, /admin/access/audit_entries
# as an authorized user, and confirm a non-authorized user is denied
```

## 17. Full worked example

The `argus_trail_demo` app built alongside this gem does all of the above
for real. Its key files, in case you want to copy the pattern directly:

- `app/models/user.rb` — `has_secure_password` + `include Argus::Trail::Actor` + `argus_trail_display_name`
- `app/controllers/application_controller.rb` — session-based `current_user`, the `Argus::Trail.current_actor` wiring, and the `rescue_from` with the `main_app.` fix
- `app/policies/application_policy.rb` + `app/policies/argus/trail/{role,permission,audit_entry}_policy.rb` — admin-only Pundit policies
- `db/seeds.rb` — creates roles/permissions via `sync_permissions!` and users via `find_or_initialize_by`, demonstrating the audit trail being populated from seed data

## 18. Uninstalling

There's no `uninstall` generator (the gem intentionally never touches your
`user.rb` automatically, so there's nothing scripted to reverse there
either). To remove:

1. Remove the `include Argus::Trail::Actor` line from your actor model.
2. Remove the `mount Argus::Trail::Engine => ...` line from `config/routes.rb`.
3. Write and run a migration dropping the five `argus_trail_*` tables.
   Nothing to drop on your own actor table — the engine never added
   anything there.
4. Remove `config/initializers/argus_trail.rb` and the gem from your Gemfile.

## 19. Optional: registering with ActiveAdmin

Argus::Trail ships its own mounted, paginated admin UI (Steps 8–9 above), so
ActiveAdmin is never required. If your app already runs ActiveAdmin and
you'd rather manage roles/permissions there instead, `ActiveAdmin.register`
is the integration point — every block below (`index`, `show`, `form`) is
ActiveAdmin's own DSL, so the resulting pages render with ActiveAdmin's own
layout, navigation, breadcrumbs, and theme automatically. There's no extra
step to "turn on" ActiveAdmin's chrome — registering the model *is* that
step.

**This is a different mechanism from `config.layout`.** `config.layout`
(Step 9) only affects the engine's *own* mounted screens
(`Argus::Trail::RolesController` etc. under `/admin/access`), and only
supports swapping in one of your **app's own** `app/views/layouts/*.erb`
files. Pointing it at ActiveAdmin's layout (e.g.
`config.layout = "active_admin"`) is **not supported and will not work** —
`Argus::Trail::ApplicationController` inherits from your app's
`ApplicationController`, not `ActiveAdmin::BaseController`, so ActiveAdmin's
layout will call helpers/instance variables (`current_admin_user`,
`active_admin_namespace`, breadcrumbs, the admin nav menu, etc.) that were
never set up for that request and it will error. If you want ActiveAdmin's
actual layout and templates, register the models below instead of trying to
reuse the engine's own mounted controllers/views.

**The one sharp edge, either way:** ActiveAdmin's default scaffolded form
binds association checkboxes straight to `permission_ids=`/`role_ids=`.
Saving through that path changes the join table but writes **no**
`AuditEntry` — `sync_permissions!`/`sync_roles!` are the only methods that
populate the audit log, and ActiveAdmin has no way to know to call them
unless you tell it to. Every `controller do ... end` override below exists
specifically to call the sync method, the same way the engine's own
`RolesController` does
([roles_controller.rb](../app/controllers/argus/trail/roles_controller.rb)).

### Registering roles

```ruby
# app/admin/argus_trail_roles.rb
ActiveAdmin.register Argus::Trail::Role, as: "Role" do
  permit_params :name, :description, permission_ids: []

  index do
    selectable_column
    id_column
    column :name
    column :description
    column("Permissions") { |role| role.permissions.count }
    column("Assigned to") { |role| role.actors.count }
    actions
  end

  show do
    attributes_table do
      row :name
      row :description
      row :created_at
      row :updated_at
    end

    panel "Permissions (#{role.permissions.count})" do
      table_for role.permissions.order(:name) do
        column :name
        column :description
      end
    end

    panel "Assigned actors (#{role.actors.count})" do
      table_for role.actors.limit(20) do
        column("Actor") { |actor| actor.try(:argus_trail_display_name) || actor.try(:email) || "##{actor.id}" }
      end
    end

    panel "Audit history" do
      para link_to "View full audit log for this role",
                   admin_audit_entries_path(q: { role_id_eq: role.id })
    end
  end

  form do |f|
    f.inputs do
      f.input :name
      f.input :description
      f.input :permissions, as: :check_boxes, collection: Argus::Trail::Permission.order(:name)
    end
    f.actions
  end

  controller do
    def create
      @role = Argus::Trail::Role.new(permitted_params[:role].except(:permission_ids))
      if @role.save
        @role.sync_permissions!(params.dig(:role, :permission_ids), changed_by: current_admin_user)
        redirect_to admin_role_path(@role), notice: "Role created."
      else
        render :new
      end
    end

    def update
      @role = Argus::Trail::Role.find(params[:id])
      if @role.update(permitted_params[:role].except(:permission_ids))
        @role.sync_permissions!(params.dig(:role, :permission_ids), changed_by: current_admin_user)
        redirect_to admin_role_path(@role), notice: "Role updated."
      else
        render :edit
      end
    end
  end
end
```

`current_admin_user` above is whatever ActiveAdmin's own authentication
gives you by default — swap in whatever your actor lookup actually is. If
you've already wired `Argus::Trail.current_actor` in your
`ApplicationController` (see [Step 5](#7-step-5--tell-the-engine-whos-acting)),
you can drop the explicit `changed_by:` argument entirely and let it fall
back to `changed_by_resolver` instead.

`admin_audit_entries_path(q: { role_id_eq: role.id })` assumes Ransack (what
ActiveAdmin's own filters use) — drop the `q:` param and it just links to
the unfiltered audit index if you haven't set that up.

### Registering an actor's roles

Same sharp edge, same fix — call `sync_roles!` instead of letting
ActiveAdmin write `role_ids=` directly:

```ruby
# in your existing app/admin/users.rb
ActiveAdmin.register User do
  permit_params :email, :name, role_ids: []

  show do
    attributes_table do
      row :email
      row :name
    end

    panel "Roles" do
      table_for user.roles.order(:name) do
        column :name
        column :description
      end
    end
  end

  form do |f|
    f.inputs do
      f.input :email
      f.input :name
      f.input :roles, as: :check_boxes, collection: Argus::Trail::Role.order(:name)
    end
    f.actions
  end

  controller do
    def update
      @user = User.find(params[:id])
      if @user.update(permitted_params[:user].except(:role_ids))
        @user.sync_roles!(params.dig(:user, :role_ids), changed_by: current_admin_user)
        redirect_to admin_user_path(@user), notice: "User updated."
      else
        render :edit
      end
    end
  end
end
```

### Registering permissions

Permissions have no assignment logic of their own, so a plain resource works
as-is:

```ruby
# app/admin/argus_trail_permissions.rb
ActiveAdmin.register Argus::Trail::Permission, as: "Permission" do
  permit_params :name, :description

  show do
    attributes_table do
      row :name
      row :description
    end

    panel "Roles granting this permission (#{permission.roles.count})" do
      table_for permission.roles.order(:name) do
        column :name
      end
    end
  end
end
```

### Registering the audit log (read-only)

Never allow create/edit/destroy here — it's meant to be append-only:

```ruby
# app/admin/argus_trail_audit_entries.rb
ActiveAdmin.register Argus::Trail::AuditEntry, as: "AuditEntry" do
  actions :index, :show

  index do
    selectable_column
    column :event_type
    column("Subject") { |entry| entry.subject_label }
    column("Role") { |entry| entry.role_name }
    column("Permission") { |entry| entry.permission_name }
    column("Changed by") { |entry| entry.changed_by_label }
    column :created_at
    actions defaults: false
  end

  show do
    attributes_table do
      row :event_type
      row("Subject") { |entry| entry.subject_label }
      row("Role") { |entry| entry.role_name }
      row("Permission") { |entry| entry.permission_name }
      row("Changed by") { |entry| entry.changed_by_label }
      row :created_at
      row :metadata
    end
  end
end
```

### Authorization is independent of `config.authorize_with`

Whichever authorization ActiveAdmin resources use (its own
`config.authorization_adapter`, typically CanCanCan or Pundit) has nothing
to do with `config.authorize_with` — that setting only gates the engine's
*own* mounted controllers (`Argus::Trail::RolesController` etc., under
`/admin/access`). If you're only going to manage these models through
ActiveAdmin, you don't need to set `authorize_with` or define Pundit
policies for the engine's controllers at all — just skip mounting
`Argus::Trail::Engine` in `config/routes.rb` (Step 8), and let ActiveAdmin's
own authorization govern access instead.

### Note on verification

The registrations above follow ActiveAdmin's documented DSL (`index`,
`show`, `form`, `controller do...end`, `permit_params`) the same way the
rest of this guide's examples were run against the `argus_trail_demo` app —
but unlike those, ActiveAdmin itself isn't a dependency of this gem or its
test suite, so these specific blocks haven't been executed against a real
ActiveAdmin install as part of CI. Treat them as a correct starting point
per ActiveAdmin's own API, and adjust to your ActiveAdmin version if
something shifts (e.g. Arbre panel/table_for syntax has been stable across
recent versions, but always worth a quick smoke test after pasting in).
