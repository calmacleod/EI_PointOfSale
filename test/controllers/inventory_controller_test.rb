# frozen_string_literal: true

require "test_helper"

class InventoryControllerTest < ActionDispatch::IntegrationTest
  setup do
    @product = products(:dragon_shield_red)
  end

  # ── show ──────────────────────────────────────────────────────────

  test "admin can view inventory page" do
    sign_in_as(users(:admin))
    get inventory_path
    assert_response :success
    assert_includes response.body, "Inventory Restock"
  end

  test "common user can view inventory page" do
    sign_in_as(users(:one))
    get inventory_path
    assert_response :success
  end

  test "unauthenticated user cannot view inventory page" do
    get inventory_path
    assert_response :redirect
  end

  # ── lookup ────────────────────────────────────────────────────────

  test "lookup returns product data for valid code" do
    sign_in_as(users(:admin))
    get lookup_inventory_path, params: { code: @product.code }, as: :json

    assert_response :success
    json = response.parsed_body
    assert json["found"]
    assert_equal @product.id, json["id"]
    assert_equal @product.code, json["code"]
    assert_equal @product.name, json["name"]
    assert_equal @product.stock_level, json["stock_level"]
  end

  test "lookup returns not found for invalid code" do
    sign_in_as(users(:admin))
    get lookup_inventory_path, params: { code: "NONEXISTENT" }, as: :json

    assert_response :success
    json = response.parsed_body
    assert_not json["found"]
  end

  test "common user can use lookup" do
    sign_in_as(users(:one))
    get lookup_inventory_path, params: { code: @product.code }, as: :json
    assert_response :success
  end

  test "lookup by product_id returns product data" do
    sign_in_as(users(:admin))
    get lookup_inventory_path, params: { product_id: @product.id }, as: :json

    assert_response :success
    json = response.parsed_body
    assert json["found"]
    assert_equal @product.id, json["id"]
  end

  # ── restock ───────────────────────────────────────────────────────

  test "admin can restock products" do
    sign_in_as(users(:admin))
    original_stock = @product.stock_level

    post restock_inventory_path, params: {
      restocks: [
        { product_id: @product.id, quantity: 10, notes: "Test" }
      ]
    }

    assert_redirected_to inventory_path
    assert_equal original_stock + 10, @product.reload.stock_level
  end

  test "common user can restock products" do
    sign_in_as(users(:one))

    post restock_inventory_path, params: {
      restocks: [
        { product_id: @product.id, quantity: 5 }
      ]
    }

    assert_redirected_to inventory_path
    assert_match(/Successfully restocked/, flash[:notice])
  end

  test "restock with no quantities shows alert" do
    sign_in_as(users(:admin))

    post restock_inventory_path, params: {
      restocks: [
        { product_id: @product.id, quantity: 0 }
      ]
    }

    assert_redirected_to inventory_path
    assert_match(/No restock quantities/, flash[:alert])
  end

  # ── import ────────────────────────────────────────────────────────

  test "import restocks from CSV" do
    sign_in_as(users(:admin))
    original_stock = @product.stock_level

    csv_content = "code,quantity,notes\n#{@product.code},15,CSV import\n"
    file = Rack::Test::UploadedFile.new(
      StringIO.new(csv_content), "text/csv", original_filename: "restock.csv"
    )

    post import_inventory_path, params: { csv_file: file }

    assert_redirected_to inventory_path
    assert_match(/CSV imported/, flash[:notice])
    assert_equal original_stock + 15, @product.reload.stock_level
  end

  test "import without file shows alert" do
    sign_in_as(users(:admin))

    post import_inventory_path

    assert_redirected_to inventory_path
    assert_match(/Please select a CSV file/, flash[:alert])
  end

  test "import with empty CSV shows alert" do
    sign_in_as(users(:admin))

    csv_content = "code,quantity,notes\n"
    file = Rack::Test::UploadedFile.new(
      StringIO.new(csv_content), "text/csv", original_filename: "empty.csv"
    )

    post import_inventory_path, params: { csv_file: file }

    assert_redirected_to inventory_path
    assert_match(/No valid rows/, flash[:alert])
  end
end
