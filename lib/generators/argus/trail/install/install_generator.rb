require "rails/generators"
require "rails/generators/migration"
require "active_record"

module Argus
  module Trail
    module Generators
      class InstallGenerator < Rails::Generators::Base
        include Rails::Generators::Migration

        source_root File.expand_path("templates", __dir__)

        class_option :actor, type: :string, default: "User",
                     desc: "Name of your actor/user model — gets `include Argus::Trail::Actor`"

        def self.next_migration_number(dirname)
          ActiveRecord::Migration.next_migration_number(current_migration_number(dirname) + 1)
        end

        def create_initializer
          template "initializer.rb", "config/initializers/argus_trail.rb"
        end

        def create_core_migration
          migration_template "create_argus_trail_tables.rb.erb",
                              "db/migrate/create_argus_trail_tables.rb"
        end

        def mount_engine
          routes_file = File.expand_path("config/routes.rb", destination_root)
          return unless File.exist?(routes_file)
          return if File.read(routes_file).include?("Argus::Trail::Engine")

          route 'mount Argus::Trail::Engine => "/admin/access"'
        end

        # No code needed beyond running this generator: opts your actor model
        # into role assignment/permission checks automatically, instead of
        # asking you to add `include Argus::Trail::Actor` by hand.
        def include_actor_concern
          model_file = File.expand_path("app/models/#{actor_file_name}.rb", destination_root)

          unless File.exist?(model_file)
            say_status :skip,
                       "app/models/#{actor_file_name}.rb not found — add `include Argus::Trail::Actor` " \
                       "to your actor model by hand (run with --actor=YourModel if it's not User)", :yellow
            return
          end

          if File.read(model_file).include?("Argus::Trail::Actor")
            say_status :skip, "app/models/#{actor_file_name}.rb already includes Argus::Trail::Actor", :blue
            return
          end

          inject_into_class model_file, options[:actor], "  include Argus::Trail::Actor\n\n"
        end

        # Likewise, wires up "who's making this change" for the audit log
        # automatically instead of asking for a manual before_action.
        def wire_current_actor
          controller_file = File.expand_path("app/controllers/application_controller.rb", destination_root)

          unless File.exist?(controller_file)
            say_status :skip,
                       "app/controllers/application_controller.rb not found — add " \
                       "`before_action { Argus::Trail.current_actor = current_user }` by hand", :yellow
            return
          end

          if File.read(controller_file).include?("Argus::Trail.current_actor")
            say_status :skip, "application_controller.rb already wires Argus::Trail.current_actor", :blue
            return
          end

          inject_into_class controller_file, "ApplicationController",
                             "  before_action { Argus::Trail.current_actor = current_user }\n\n"
        end

        def show_readme
          readme "POST_INSTALL" if behavior == :invoke
        end

        private

        def migration_version
          "[#{ActiveRecord::Migration.current_version}]"
        end

        def actor_file_name
          options[:actor].underscore
        end
      end
    end
  end
end
