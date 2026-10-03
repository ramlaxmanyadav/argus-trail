require "test_helper"

class ActorTest < ActiveSupport::TestCase
  setup do
    @changer = User.create!(email: "changer-#{SecureRandom.hex(4)}@example.com")
    @role_a = Argus::Trail::Role.create!(name: "role-a-#{SecureRandom.hex(4)}", description: "desc")
    @role_b = Argus::Trail::Role.create!(name: "role-b-#{SecureRandom.hex(4)}", description: "desc")
    Argus::Trail.current_actor = @changer
  end

  teardown do
    Argus::Trail.current_actor = nil
  end

  test "sync_roles! assigns new roles and records an audit entry per assignment" do
    user = User.create!(email: "user-#{SecureRandom.hex(4)}@example.com")

    assert_difference -> { Argus::Trail::AuditEntry.where(event_type: "role_assigned").count }, 2 do
      user.sync_roles!([ @role_a.id, @role_b.id ], changed_by: @changer)
    end

    assert_equal [ @role_a.id, @role_b.id ].sort, user.reload.role_ids.sort

    entry = Argus::Trail::AuditEntry.where(event_type: "role_assigned", role_id: @role_a.id).last
    assert_equal user, entry.subject
    assert_equal @changer, entry.changed_by
    assert_equal @role_a.name, entry.role_name
  end

  test "sync_roles! revokes roles no longer present and records an audit entry per revoke" do
    user = User.create!(email: "user-#{SecureRandom.hex(4)}@example.com")
    user.sync_roles!([ @role_a.id, @role_b.id ], changed_by: @changer)

    assert_difference -> { Argus::Trail::AuditEntry.where(event_type: "role_revoked").count }, 1 do
      user.sync_roles!([ @role_a.id ], changed_by: @changer)
    end

    assert_equal [ @role_a.id ], user.reload.role_ids

    entry = Argus::Trail::AuditEntry.where(event_type: "role_revoked").last
    assert_equal @role_b.id, entry.role_id
  end

  test "sync_roles! writes no audit entries when the set is unchanged" do
    user = User.create!(email: "user-#{SecureRandom.hex(4)}@example.com")
    user.sync_roles!([ @role_a.id ], changed_by: @changer)

    assert_no_difference -> { Argus::Trail::AuditEntry.count } do
      user.sync_roles!([ @role_a.id ], changed_by: @changer)
    end
  end

  test "an actor can hold multiple roles at once" do
    user = User.create!(email: "user-#{SecureRandom.hex(4)}@example.com")
    user.sync_roles!([ @role_a.id, @role_b.id ], changed_by: @changer)

    assert_equal [ @role_a, @role_b ].sort_by(&:id), user.roles.order(:id)
    assert_includes @role_a.actors, user
    assert_includes @role_b.actors, user
  end

  test "has_permission? delegates to any of the assigned roles" do
    permission = Argus::Trail::Permission.create!(name: "perm-#{SecureRandom.hex(4)}", description: "desc")
    @role_b.sync_permissions!([ permission.id ], changed_by: @changer)

    user = User.create!(email: "user-#{SecureRandom.hex(4)}@example.com")
    user.sync_roles!([ @role_a.id, @role_b.id ], changed_by: @changer)

    assert user.has_permission?(permission.name)
    assert_not user.has_permission?("does_not_exist")
  end

  test "has_permission? matches module-wise permissions by module_name and action" do
    permission = Argus::Trail::Permission.create!(module_name: "admin/accounts", action: "read")
    @role_b.sync_permissions!([ permission.id ], changed_by: @changer)

    user = User.create!(email: "user-#{SecureRandom.hex(4)}@example.com")
    user.sync_roles!([ @role_b.id ], changed_by: @changer)

    assert user.has_permission?("admin/accounts", :read)
    assert_not user.has_permission?("admin/accounts", :update)
    assert_not user.has_permission?("admin/charges", :read)
  end

  test "has_permission? is memoized per actor instance, avoiding repeat queries" do
    permission = Argus::Trail::Permission.create!(module_name: "admin/accounts", action: "read")
    @role_b.sync_permissions!([ permission.id ], changed_by: @changer)

    user = User.create!(email: "user-#{SecureRandom.hex(4)}@example.com")
    user.sync_roles!([ @role_b.id ], changed_by: @changer)

    assert user.has_permission?("admin/accounts", :read)

    query_count = 0
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      query_count += 1 unless payload[:name] == "SCHEMA"
    end
    begin
      3.times { user.has_permission?("admin/accounts", :read) }
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber)
    end

    assert_equal 0, query_count, "expected has_permission? to be memoized instead of re-querying"
  end

  test "sync_roles! clears the has_permission? cache so a later check sees the change" do
    permission = Argus::Trail::Permission.create!(module_name: "admin/accounts", action: "read")
    @role_b.sync_permissions!([ permission.id ], changed_by: @changer)

    user = User.create!(email: "user-#{SecureRandom.hex(4)}@example.com")
    assert_not user.has_permission?("admin/accounts", :read)

    user.sync_roles!([ @role_b.id ], changed_by: @changer)

    assert user.has_permission?("admin/accounts", :read)
  end

  test "destroying an actor destroys its role assignments" do
    user = User.create!(email: "user-#{SecureRandom.hex(4)}@example.com")
    user.sync_roles!([ @role_a.id ], changed_by: @changer)

    assert_difference -> { Argus::Trail::RoleAssignment.count }, -1 do
      user.destroy
    end
  end
end
