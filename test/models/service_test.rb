require "test_helper"

class ServiceTest < ActiveSupport::TestCase
  test "valid with name and price" do
    service = Service.new(
      name: "Test Service",
      price: 9.99,
      tax_code: tax_codes(:one),
      added_by: users(:admin)
    )
    assert service.valid?
  end

  test "invalid without name" do
    service = Service.new(name: nil, price: 9.99)
    assert_not service.valid?
  end

  test "invalid without price" do
    service = Service.new(name: "Test", price: nil)
    assert_not service.valid?
  end

  test "has categories through categorizations" do
    service = services(:printer_refill)
    assert service.categories.any?
  end

  test "discards" do
    service = services(:printer_refill)
    service.discard
    assert service.discarded?
  end
end
