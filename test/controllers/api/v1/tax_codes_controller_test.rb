# frozen_string_literal: true

require "test_helper"

class Api::V1::TaxCodesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @tax_code = tax_codes(:one)
  end

  test "sync requires authentication" do
    get api_v1_tax_codes_sync_path, as: :json

    assert_response :redirect
  end

  test "sync returns all active tax codes as JSON" do
    sign_in_as(users(:admin))

    get api_v1_tax_codes_sync_path, as: :json

    assert_response :success
    body = response.parsed_body
    assert body.key?("synced_at")
    assert body.key?("tax_codes")
    assert body["tax_codes"].is_a?(Array)

    tc_data = body["tax_codes"].find { |t| t["id"] == @tax_code.id }
    assert_not_nil tc_data
    assert_equal @tax_code.code, tc_data["code"]
    assert_equal @tax_code.name, tc_data["name"]
    assert_equal @tax_code.rate.to_s, tc_data["rate"]
    assert tc_data.key?("exemption_type")
    assert tc_data.key?("updated_at")
  end

  test "sync works for common users" do
    sign_in_as(users(:one))

    get api_v1_tax_codes_sync_path, as: :json

    assert_response :success
  end

  test "sync with since param returns only updated tax codes" do
    sign_in_as(users(:admin))
    future = 1.year.from_now.iso8601

    get api_v1_tax_codes_sync_path, params: { since: future }, as: :json

    assert_response :success
    body = response.parsed_body
    assert_empty body["tax_codes"]
  end

  test "delta sync returns tax codes deleted after the previous sync" do
    sign_in_as(users(:admin))
    since = 1.minute.ago
    @tax_code.update!(discarded_at: Time.current)

    get api_v1_tax_codes_sync_path, params: { since: since.iso8601 }, as: :json

    assert_response :success
    assert_includes response.parsed_body["deleted_ids"], @tax_code.id
    assert_not_includes response.parsed_body["tax_codes"].pluck("id"), @tax_code.id
  end
end
