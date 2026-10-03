namespace :argus_trail do
  desc "Scan your app's routes and create any missing module-wise Argus::Trail::Permission records"
  task fetch_permissions: :environment do
    permission_class = Argus::Trail.config.permission_class
    pairs = Argus::Trail::PermissionScanner.scan
    existing = permission_class.module_wise.pluck(:module_name, :action).to_set

    created = pairs.reject { |pair| existing.include?(pair) }.map do |module_name, action|
      permission_class.create!(module_name: module_name, action: action)
    end

    puts "Argus::Trail: scanned #{pairs.size} controller/action pair(s), " \
         "created #{created.size} new permission(s)."
    created.each { |permission| puts "  + #{permission.module_name}##{permission.action}" }
  end

  namespace :fetch_permissions do
    desc "Remove module-wise Argus::Trail::Permission records whose route no longer exists " \
         "and that aren't granted to any role"
    task prune: :environment do
      permission_class = Argus::Trail.config.permission_class
      current_pairs = Argus::Trail::PermissionScanner.scan.to_set

      orphaned = permission_class.module_wise.reject { |permission| current_pairs.include?([ permission.module_name, permission.action ]) }
      removable, blocked = orphaned.partition { |permission| permission.roles.none? }

      removable.each(&:destroy!)

      puts "Argus::Trail: removed #{removable.size} orphaned permission(s)."
      removable.each { |permission| puts "  - #{permission.module_name}##{permission.action}" }

      if blocked.any?
        puts "Argus::Trail: left #{blocked.size} orphaned permission(s) in place — still granted to a role:"
        blocked.each do |permission|
          puts "  ! #{permission.module_name}##{permission.action} (role(s): #{permission.roles.pluck(:name).join(', ')})"
        end
      end
    end
  end
end
