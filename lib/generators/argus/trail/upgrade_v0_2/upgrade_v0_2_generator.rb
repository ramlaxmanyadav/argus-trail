require "rails/generators"
require "rails/generators/migration"
require "active_record"

module Argus
  module Trail
    module Generators
      # Upgrade path for a host that installed argus-trail before module-wise
      # permissions existed (argus_trail_permissions had no module_name/action
      # columns, argus_trail_audit_entries had no index on created_at). A
      # fresh install never needs this — create_argus_trail_tables already
      # includes both — this generator exists purely for pre-existing hosts
      # upgrading the gem in place.
      #
      # Usage: bin/rails generate argus:trail:upgrade_v0_2 && bin/rails db:migrate
      class UpgradeV02Generator < Rails::Generators::Base
        include Rails::Generators::Migration

        source_root File.expand_path("templates", __dir__)

        def self.next_migration_number(dirname)
          ActiveRecord::Migration.next_migration_number(current_migration_number(dirname) + 1)
        end

        def create_upgrade_migration
          migration_template "add_module_wise_permissions_and_audit_index.rb.erb",
                              "db/migrate/argus_trail_add_module_wise_permissions_and_audit_index.rb"
        end

        def show_readme
          readme "POST_INSTALL" if behavior == :invoke
        end

        private

        def migration_version
          "[#{ActiveRecord::Migration.current_version}]"
        end
      end
    end
  end
end
