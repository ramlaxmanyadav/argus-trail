require "test_helper"

class FetchPermissionsTaskTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("argus_trail:fetch_permissions")
    Rake::Task["argus_trail:fetch_permissions"].reenable
    Rake::Task["argus_trail:fetch_permissions:prune"].reenable
  end

  test "fetch_permissions creates missing module-wise permissions from routes, without duplicating" do
    assert_difference -> { Argus::Trail::Permission.module_wise.count }, +1 do
      Rake::Task["argus_trail:fetch_permissions"].invoke
    end

    assert Argus::Trail::Permission.module_wise.exists?(module_name: "widgets", action: "read")

    Rake::Task["argus_trail:fetch_permissions"].reenable
    assert_no_difference -> { Argus::Trail::Permission.count } do
      Rake::Task["argus_trail:fetch_permissions"].invoke
    end
  end

  test "fetch_permissions:prune removes orphaned, unassigned permissions but keeps ones still granted to a role" do
    granted = Argus::Trail::Permission.create!(module_name: "widgets", action: "archive")
    unassigned = Argus::Trail::Permission.create!(module_name: "widgets", action: "nuke")
    role = Argus::Trail::Role.create!(name: "widget-admin-#{SecureRandom.hex(4)}", description: "desc")
    role.sync_permissions!([ granted.id ])

    Rake::Task["argus_trail:fetch_permissions:prune"].invoke

    assert Argus::Trail::Permission.exists?(granted.id)
    assert_not Argus::Trail::Permission.exists?(unassigned.id)
  end
end
