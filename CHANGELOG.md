# Changelog

## 0.2.0

**Upgrading from 0.1.x? Run this first:**

```bash
bin/rails generate argus:trail:upgrade_v0_2
bin/rails db:migrate
```

This adds `module_name`/`action` columns to `argus_trail_permissions`, a
composite index on them, and an index on `argus_trail_audit_entries.created_at`.
Safe to run on any install — every step is guarded and a no-op if already
applied.

### Added

- **Module-wise permissions**: `Permission` now supports `module_name`/`action`
  (e.g. `module_name: "admin/accounts", action: "read"`) alongside the
  existing flat `name`/`description` permissions. Name/description auto-derive
  when both are set. The role/permission admin screens group these by module
  with a "select all" toggle.
- **`bin/rails argus_trail:fetch_permissions`**: scans your app's routes and
  creates a `Permission` for every controller/action pair found (skipping the
  engine's own routes and framework-internal ones), safe to rerun —  only
  ever adds. `argus_trail:fetch_permissions:prune` removes permissions whose
  route is gone and aren't granted to any role.
- **`Argus::Trail::Authorizable`**: a controller concern — `include
  Argus::Trail::Authorizable` gates every action behind the matching
  module-wise permission automatically, no further code needed.
- **Plug-and-play install**: the install generator now auto-injects `include
  Argus::Trail::Actor` into your actor model and the `current_actor`
  before_action into `ApplicationController` (idempotent, skips gracefully if
  the files don't exist yet).
- **No more hard-fail without Pundit**: the admin screens default to "any
  signed-in actor" when neither Pundit policies nor `config.authorize_with`
  are set, instead of raising `MissingAuthorization`. Tighten with a policy
  or `authorize_with` as before.
- `Actor#has_permission?` now accepts either a plain permission name or a
  `(module_name, action)` pair, and is memoized per actor instance (cleared
  by `sync_roles!`) so repeated checks in one request don't re-query.
- `config.permission_scan_excludes` and `config.action_name_mapper` to
  customize what `fetch_permissions`/`Authorizable` scan and how actions
  normalize.

### Fixed

- `roles#index`/`permissions#index` called `.count` on an already-preloaded
  association inside the row loop — `.count` always re-queries regardless of
  `includes`, unlike `.size`. Switched to `.size` (no behavior change, fewer
  queries).
- Added the missing index on `argus_trail_audit_entries.created_at` — used by
  both the default `.recent` ordering and the "Today" stat on every page load
  of what's an append-only, ever-growing table.

## 0.1.1 / 0.1.0

Initial mountable-engine release: roles, permissions, role assignments, and
a unified audit log, with paginated HTML admin screens and install/views/config
generators.
