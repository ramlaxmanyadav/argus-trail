require "rails/generators"
require_relative "../install/install_generator"

module Argus
  module Trail
    module Generators
      # Re-templates just the initializer — for hosts who already ran
      # `install` (migrations + route already in place) and want the
      # config/initializers/argus_trail.rb file regenerated.
      class ConfigGenerator < Rails::Generators::Base
        source_root Argus::Trail::Generators::InstallGenerator.source_root

        desc "Writes (or rewrites) config/initializers/argus_trail.rb"

        def create_initializer
          template "initializer.rb", "config/initializers/argus_trail.rb"
        end
      end
    end
  end
end
