require_relative "lib/argus/trail/version"

Gem::Specification.new do |spec|
  spec.name        = "argus-trail"
  spec.version     = Argus::Trail::VERSION
  spec.authors     = [ "Ram Laxman Yadav" ]
  spec.email       = [ "yadavramlaxman@gmail.com" ]
  spec.summary     = "Mountable Rails engine for roles, permissions, and an audit trail of who changed what."
  spec.description = "Plug-and-play role/permission management with module-wise permissions generated from " \
                      "your own routes, one-line controller enforcement, and a unified audit log of role " \
                      "reassignments and permission grants/revokes — shipped as a mountable engine with " \
                      "paginated HTML admin screens and generators for install/views/config. Agnostic to auth " \
                      "(works standalone, auto-integrates with Pundit) and pagination (auto-integrates with " \
                      "Kaminari)."
  spec.license     = "MIT"

  # The docs site (below) is the project's actual front door — a real landing
  # page with the pitch, a quick-start, and the comparison table — so it gets
  # top billing as spec.homepage. The GitHub repo is still one click away via
  # source_code_uri.
  spec.homepage = "https://ramlaxmanyadav.github.io/argus-trail/"

  # `homepage_uri` is deliberately omitted from metadata — it would just
  # duplicate spec.homepage above with the same URL, which RubyGems warns
  # about at build time (only one of the two gets shown on the gem page).
  spec.metadata = {
    "source_code_uri"       => "https://github.com/ramlaxmanyadav/argus-trail",
    "documentation_uri"     => "https://ramlaxmanyadav.github.io/argus-trail/",
    "changelog_uri"         => "https://github.com/ramlaxmanyadav/argus-trail/blob/main/CHANGELOG.md",
    "bug_tracker_uri"       => "https://github.com/ramlaxmanyadav/argus-trail/issues",
    "rubygems_mfa_required" => "true"
  }

  spec.required_ruby_version = ">= 3.1"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md", "CHANGELOG.md"]
  end

  # Only a hard dependency on Rails itself. Pundit and Kaminari are soft
  # dependencies detected at runtime via `defined?` — see lib/argus/trail/configuration.rb
  # and lib/argus/trail/pagination.rb — so hosts are never forced to install either.
  spec.add_dependency "rails", ">= 6.1"
end
