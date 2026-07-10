require "rails/generators"
require "rails/generators/migration"
require "active_record"

module Argus
  module Trail
    module Generators
      class InstallGenerator < Rails::Generators::Base
        include Rails::Generators::Migration

        source_root File.expand_path("templates", __dir__)

        class_option :actor_table, type: :string, default: "users",
                     desc: "Table to add the role_id foreign key to (your User/Account table)"

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

        def create_actor_migration
          migration_template "add_role_to_actor_table.rb.erb",
                              "db/migrate/add_role_to_#{actor_table}.rb"
        end

        def mount_engine
          routes_file = File.expand_path("config/routes.rb", destination_root)
          return unless File.exist?(routes_file)
          return if File.read(routes_file).include?("Argus::Trail::Engine")

          route 'mount Argus::Trail::Engine => "/admin/access"'
        end

        def show_readme
          readme "POST_INSTALL" if behavior == :invoke
        end

        private

        def actor_table
          options[:actor_table]
        end

        def migration_version
          "[#{ActiveRecord::Migration.current_version}]"
        end
      end
    end
  end
end
