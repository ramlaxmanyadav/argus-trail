require_relative "lib/argus/trail/version"

Gem::Specification.new do |spec|
  spec.name        = "argus-trail"
  spec.version     = Argus::Trail::VERSION
  spec.authors     = [ "Ram Laxman Yadav" ]
  spec.email       = [ "yadavramlaxman@gmail.com" ]
  spec.homepage    = "https://github.com/ramlaxmanyadav/argus-trail"
  spec.summary     = "Mountable Rails engine for roles, permissions, and an audit trail of who changed what."
  spec.description = "Plug-and-play role/permission management with a unified audit log of role reassignments " \
                      "and permission grants/revokes, shipped as a mountable engine with paginated HTML admin " \
                      "screens and generators for install/views/config. Agnostic to auth (works standalone, " \
                      "auto-integrates with Pundit) and pagination (auto-integrates with Kaminari)."
  spec.license     = "MIT"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage

  spec.required_ruby_version = ">= 3.1"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  # Only a hard dependency on Rails itself. Pundit and Kaminari are soft
  # dependencies detected at runtime via `defined?` — see lib/argus/trail/configuration.rb
  # and lib/argus/trail/pagination.rb — so hosts are never forced to install either.
  spec.add_dependency "rails", ">= 6.1"
end
