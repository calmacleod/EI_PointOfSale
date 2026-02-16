# frozen_string_literal: true

require "test_helper"

class SavedQueryTest < ActiveSupport::TestCase
  test "valid with all required attributes" do
    query = SavedQuery.new(
      name: "Test query",
      resource_type: "products",
      query_params: { q: "test" },
      user: users(:one)
    )
    assert query.valid?
  end

  test "requires name" do
    query = SavedQuery.new(resource_type: "products", user: users(:one))
    assert_not query.valid?
    assert_includes query.errors[:name], "can't be blank"
  end

  test "requires resource_type" do
    query = SavedQuery.new(name: "Test", user: users(:one))
    assert_not query.valid?
    assert_includes query.errors[:resource_type], "can't be blank"
  end

  test "for_resource scope filters by resource_type" do
    user = users(:one)
    product_queries = user.saved_queries.for_resource("products")
    customer_queries = user.saved_queries.for_resource("customers")

    assert product_queries.any?
    assert customer_queries.any?
    assert product_queries.all? { |sq| sq.resource_type == "products" }
    assert customer_queries.all? { |sq| sq.resource_type == "customers" }
  end

  test "belongs to user" do
    query = saved_queries(:product_filter)
    assert_equal users(:one), query.user
  end

  test "user can have multiple saved queries" do
    user = users(:one)
    assert user.saved_queries.count >= 2
  end

  test "destroying user destroys saved queries" do
    user = User.create!(
      name: "Temp",
      email_address: "temp@example.com",
      password: "password",
      password_confirmation: "password"
    )
    user.saved_queries.create!(name: "Test", resource_type: "products", query_params: {})

    assert_difference "SavedQuery.count", -1 do
      user.destroy
    end
  end
end
