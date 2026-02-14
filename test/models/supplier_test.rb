require "test_helper"

class SupplierTest < ActiveSupport::TestCase
  test "valid with name" do
    supplier = Supplier.new(name: "Test Supplier")
    assert supplier.valid?
  end

  test "invalid without name" do
    supplier = Supplier.new(name: nil)
    assert_not supplier.valid?
  end

  test "discards" do
    supplier = suppliers(:jf_sports)
    supplier.discard
    assert supplier.discarded?
  end
end
