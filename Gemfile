source "https://rubygems.org"

# Specify your gem's dependencies in argus-trail.gemspec.
gemspec

gem "puma"

gem "sqlite3"

gem "propshaft"

# Soft dependencies — the engine works without these, but the dummy app
# bundles both so the test suite can exercise the Pundit/Kaminari integration
# paths alongside the standalone fallback paths.
gem "pundit"
gem "kaminari"

# Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
gem "rubocop-rails-omakase", require: false

# Start debugger with binding.b [https://github.com/ruby/debug]
# gem "debug", ">= 1.0.0"
