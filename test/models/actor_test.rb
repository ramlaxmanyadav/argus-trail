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

  test "assigning a role records a role_assigned audit entry with from/to" do
    user = User.create!(email: "user-#{SecureRandom.hex(4)}@example.com")

    assert_difference -> { Argus::Trail::AuditEntry.where(event_type: "role_assigned").count }, 1 do
      user.update!(role: @role_a)
    end

    entry = Argus::Trail::AuditEntry.where(event_type: "role_assigned").last
    assert_equal user, entry.subject
    assert_nil entry.from_role
    assert_equal @role_a, entry.role
    assert_equal @changer, entry.changed_by

    assert_difference -> { Argus::Trail::AuditEntry.where(event_type: "role_assigned").count }, 1 do
      user.update!(role: @role_b)
    end

    entry = Argus::Trail::AuditEntry.where(event_type: "role_assigned").last
    assert_equal @role_a, entry.from_role
    assert_equal @role_b, entry.role
  end

  test "has_permission? delegates to the assigned role" do
    permission = Argus::Trail::Permission.create!(name: "perm-#{SecureRandom.hex(4)}", description: "desc")
    @role_a.sync_permissions!([ permission.id ], changed_by: @changer)
    user = User.create!(email: "user-#{SecureRandom.hex(4)}@example.com", role: @role_a)

    assert user.has_permission?(permission.name)
    assert_not user.has_permission?("does_not_exist")
  end

  test "saving without changing role writes no audit entry" do
    user = User.create!(email: "user-#{SecureRandom.hex(4)}@example.com", role: @role_a)

    assert_no_difference -> { Argus::Trail::AuditEntry.count } do
      user.update!(name: "renamed")
    end
  end
end
