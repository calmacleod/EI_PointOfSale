# frozen_string_literal: true

require "test_helper"

module AdminArea
  class AuditsControllerTest < ActionDispatch::IntegrationTest
    setup do
      sign_in_as(users(:admin))
    end

    test "index lists audits" do
      get admin_audits_path

      assert_response :success
      assert_equal "Audit Trail", inertia_props["title"]
      assert_equal "resource_index", inertia_props["view"]
    end

    test "show displays audit with changes" do
      store = Store.current
      store.update!(name: "Updated Store Name")
      audit = store.audits.last

      get admin_audit_path(audit)

      assert_response :success
      assert_equal "Audit ##{audit.id}", inertia_props["title"]
      details = inertia_props["details"].to_h { |detail| [ detail["label"], detail["value"] ] }
      assert_equal "update", details["Action"]
      assert_equal "Store", details["Model"]
      assert_includes details["Changes"].to_json, "Updated Store Name"
    end

    test "non-admin cannot access audits" do
      sign_in_as(users(:one))

      get admin_audits_path

      assert_redirected_to root_path
    end
  end
end
