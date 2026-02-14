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
      assert_includes response.body, "Audit trail"
    end

    test "show displays audit with changes" do
      store = Store.current
      store.update!(name: "Updated Store Name")
      audit = store.audits.last

      get admin_audit_path(audit)

      assert_response :success
      assert_includes response.body, "Audit ##{audit.id}"
      assert_includes response.body, "update"
      assert_includes response.body, "Store"
      assert_includes response.body, "Updated Store Name"
    end

    test "non-admin cannot access audits" do
      sign_in_as(users(:one))

      get admin_audits_path

      assert_redirected_to root_path
    end
  end
end
