require "test_helper"

class StoreTest < ActiveSupport::TestCase
  test "address formats all address parts" do
    store = Store.new(
      address_line1: "123 Main St",
      address_line2: "Suite 100",
      city: "Toronto",
      province: "ON",
      postal_code: "M5V 1A1",
      country: "Canada"
    )
    assert_equal "123 Main St, Suite 100, Toronto, ON, M5V 1A1, Canada", store.address
  end

  test "address omits blank parts" do
    store = Store.new(address_line1: "456 Oak Ave", city: "Vancouver", province: "BC")
    assert_equal "456 Oak Ave, Vancouver, BC", store.address
  end
end
