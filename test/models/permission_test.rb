require "test_helper"

class PermissionTest < ActiveSupport::TestCase
  test "module-wise permissions derive their name and description automatically" do
    permission = Argus::Trail::Permission.create!(module_name: "admin/accounts", action: "read")

    assert_equal "admin/accounts#read", permission.name
    assert_equal "Read access to Admin/accounts", permission.description
  end

  test "a manually created permission keeps its own name and description" do
    permission = Argus::Trail::Permission.create!(name: "manage_billing", description: "Can manage billing")

    assert_nil permission.module_name
    assert_not permission.module_permission?
    assert_equal "manage_billing", permission.name
  end

  test "action is unique within a module but the same action can repeat across modules" do
    Argus::Trail::Permission.create!(module_name: "admin/accounts", action: "read")

    duplicate = Argus::Trail::Permission.new(module_name: "admin/accounts", action: "read")
    assert_not duplicate.valid?

    other_module = Argus::Trail::Permission.new(module_name: "admin/charges", action: "read")
    assert other_module.valid?
  end

  test "display_name combines module and action, humanized" do
    permission = Argus::Trail::Permission.create!(module_name: "admin/accounts", action: "read")
    assert_equal "Admin/accounts — Read", permission.display_name

    manual = Argus::Trail::Permission.create!(name: "manage_billing", description: "desc")
    assert_equal "Manage billing", manual.display_name
  end

  test "grouped_by_module buckets permissions by module_name, nil for module-less ones" do
    Argus::Trail::Permission.create!(module_name: "admin/accounts", action: "read")
    Argus::Trail::Permission.create!(module_name: "admin/accounts", action: "update")
    Argus::Trail::Permission.create!(module_name: "admin/charges", action: "read")
    Argus::Trail::Permission.create!(name: "manage_billing", description: "desc")

    grouped = Argus::Trail::Permission.grouped_by_module

    assert_equal %w[admin/accounts admin/charges], grouped.keys.compact.sort
    assert_equal 2, grouped["admin/accounts"].size
    assert_equal [ nil ], grouped.keys.select(&:nil?)
  end
end
