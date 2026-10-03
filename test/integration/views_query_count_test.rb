require "test_helper"

class ViewsQueryCountTest < ActionDispatch::IntegrationTest
  test "roles#index preloads permissions instead of counting them per row" do
    admin = User.create!(email: "admin-#{SecureRandom.hex(4)}@example.com", admin: true)

    permissions = Array.new(4) { |i| Argus::Trail::Permission.create!(name: "perm-#{i}-#{SecureRandom.hex(4)}", description: "desc") }
    role_a = Argus::Trail::Role.create!(name: "role-a-#{SecureRandom.hex(4)}", description: "desc")
    role_a.sync_permissions!(permissions.map(&:id), changed_by: admin)
    role_b = Argus::Trail::Role.create!(name: "role-b-#{SecureRandom.hex(4)}", description: "desc")
    role_b.sync_permissions!([ permissions.first.id ], changed_by: admin)

    permission_queries = 0
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      permission_queries += 1 if payload[:sql]&.match?(/argus_trail_permissions/i)
    end
    begin
      get "/argus-trail/roles"
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber)
    end

    assert_response :success
    assert_operator permission_queries, :<=, 2,
      "expected role.permissions.size (preloaded) to add ~0 queries, not re-query per row like .count would (got #{permission_queries} queries touching argus_trail_permissions)"
  end

  test "permissions#index preloads roles instead of counting them per row" do
    admin = User.create!(email: "admin-#{SecureRandom.hex(4)}@example.com", admin: true)

    permission_a = Argus::Trail::Permission.create!(name: "perm-a-#{SecureRandom.hex(4)}", description: "desc")
    permission_b = Argus::Trail::Permission.create!(name: "perm-b-#{SecureRandom.hex(4)}", description: "desc")
    3.times do
      role = Argus::Trail::Role.create!(name: "role-#{SecureRandom.hex(4)}", description: "desc")
      role.sync_permissions!([ permission_a.id, permission_b.id ], changed_by: admin)
    end

    role_queries = 0
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      role_queries += 1 if payload[:sql]&.match?(/argus_trail_roles/i)
    end
    begin
      get "/argus-trail/permissions"
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber)
    end

    assert_response :success
    assert_operator role_queries, :<=, 2,
      "expected permission.roles.size (preloaded) to add ~0 queries, not re-query per row like .count would (got #{role_queries} queries touching argus_trail_roles)"
  end
end
