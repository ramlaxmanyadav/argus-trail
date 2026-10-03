require "test_helper"

class AuthorizableTest < ActionDispatch::IntegrationTest
  test "rejects the request when no actor is signed in" do
    get widgets_path
    assert_response :forbidden
  end

  test "rejects a signed-in actor without the matching permission" do
    User.create!(email: "widget-viewer-#{SecureRandom.hex(4)}@example.com")

    get widgets_path
    assert_response :forbidden
  end

  test "allows a signed-in actor whose role grants the module-wise permission" do
    user = User.create!(email: "widget-viewer-#{SecureRandom.hex(4)}@example.com")
    permission = Argus::Trail::Permission.create!(module_name: "widgets", action: "read")
    role = Argus::Trail::Role.create!(name: "widget-viewer-#{SecureRandom.hex(4)}", description: "desc")
    role.sync_permissions!([ permission.id ])
    user.sync_roles!([ role.id ])

    get widgets_path
    assert_response :success
  end

  test "does not grant access when the assigned permission is for a different module/action" do
    user = User.create!(email: "widget-viewer-#{SecureRandom.hex(4)}@example.com")
    permission = Argus::Trail::Permission.create!(module_name: "widgets", action: "create")
    role = Argus::Trail::Role.create!(name: "widget-creator-#{SecureRandom.hex(4)}", description: "desc")
    role.sync_permissions!([ permission.id ])
    user.sync_roles!([ role.id ])

    get widgets_path
    assert_response :forbidden
  end
end
