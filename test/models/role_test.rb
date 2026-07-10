require "test_helper"

class RoleTest < ActiveSupport::TestCase
  setup do
    @actor = User.create!(email: "actor-#{SecureRandom.hex(4)}@example.com")
    @role = Argus::Trail::Role.create!(name: "role-#{SecureRandom.hex(4)}", description: "desc")
    @perm_a = Argus::Trail::Permission.create!(name: "perm_a_#{SecureRandom.hex(4)}", description: "desc")
    @perm_b = Argus::Trail::Permission.create!(name: "perm_b_#{SecureRandom.hex(4)}", description: "desc")
  end

  test "sync_permissions! grants new permissions and records an audit entry per grant" do
    assert_difference -> { Argus::Trail::AuditEntry.where(event_type: "permission_granted").count }, 2 do
      @role.sync_permissions!([ @perm_a.id, @perm_b.id ], changed_by: @actor)
    end

    assert_equal [ @perm_a.id, @perm_b.id ].sort, @role.reload.permission_ids.sort

    entry = Argus::Trail::AuditEntry.where(event_type: "permission_granted", permission_id: @perm_a.id).last
    assert_equal @role, entry.subject
    assert_equal @actor, entry.changed_by
    assert_equal @perm_a.name, entry.permission_name
  end

  test "sync_permissions! revokes permissions no longer present and records an audit entry per revoke" do
    @role.sync_permissions!([ @perm_a.id, @perm_b.id ], changed_by: @actor)

    assert_difference -> { Argus::Trail::AuditEntry.where(event_type: "permission_revoked").count }, 1 do
      @role.sync_permissions!([ @perm_a.id ], changed_by: @actor)
    end

    assert_equal [ @perm_a.id ], @role.reload.permission_ids

    entry = Argus::Trail::AuditEntry.where(event_type: "permission_revoked").last
    assert_equal @perm_b.id, entry.permission_id
  end

  test "sync_permissions! writes no audit entries when the set is unchanged" do
    @role.sync_permissions!([ @perm_a.id ], changed_by: @actor)

    assert_no_difference -> { Argus::Trail::AuditEntry.count } do
      @role.sync_permissions!([ @perm_a.id ], changed_by: @actor)
    end
  end
end
