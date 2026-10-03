require "test_helper"

class PermissionScannerTest < ActiveSupport::TestCase
  test "scans the dummy app's routes into normalized module_name/action pairs" do
    pairs = Argus::Trail::PermissionScanner.scan

    assert_includes pairs, [ "widgets", "read" ]
  end

  test "excludes the engine's own mounted routes" do
    pairs = Argus::Trail::PermissionScanner.scan

    assert pairs.none? { |module_name, _| module_name.start_with?("argus/trail/") },
           "expected no argus/trail/* controller to be scanned, got: #{pairs.inspect}"
  end

  test "honors config.permission_scan_excludes" do
    Argus::Trail.config.permission_scan_excludes = [ "widgets" ]
    pairs = Argus::Trail::PermissionScanner.scan

    assert pairs.none? { |module_name, _| module_name == "widgets" }
  ensure
    Argus::Trail.config.permission_scan_excludes = []
  end

  test "honors a custom config.action_name_mapper" do
    Argus::Trail.config.action_name_mapper = ->(action) { action.to_s.upcase }
    pairs = Argus::Trail::PermissionScanner.scan

    assert_includes pairs, [ "widgets", "INDEX" ]
  ensure
    Argus::Trail.config.action_name_mapper = Argus::Trail::Configuration.new.action_name_mapper
  end
end
