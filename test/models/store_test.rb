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

  test "valid accent color is accepted" do
    store = stores(:one)
    Store::ACCENT_COLOR_NAMES.each do |color|
      store.accent_color = color
      assert store.valid?, "#{color} should be a valid accent color"
    end
  end

  test "invalid accent color is rejected" do
    store = stores(:one)
    store.accent_color = "neon_pink"
    assert_not store.valid?
    assert_includes store.errors[:accent_color], "is not included in the list"
  end

  test "accent_palette returns the correct palette for the configured color" do
    store = stores(:one)
    store.accent_color = "blue"
    palette = store.accent_palette
    assert_equal "Blue", palette[:label]
    assert_equal "#2563eb", palette[:light]
  end

  test "accent_palette falls back to teal for unknown color" do
    store = Store.new(name: "Test")
    # Bypass validation to test fallback
    store.instance_variable_set(:@accent_color, "unknown")
    store.define_singleton_method(:accent_color) { "unknown" }
    palette = store.accent_palette
    assert_equal "Teal", palette[:label]
  end

  test "ACCENT_COLORS constant has expected keys" do
    expected = %w[teal blue indigo emerald amber rose violet slate]
    assert_equal expected, Store::ACCENT_COLOR_NAMES
  end

  test "each accent color has all required keys" do
    required_keys = %i[label light light_hover dark dark_hover swatch]
    Store::ACCENT_COLORS.each do |name, palette|
      required_keys.each do |key|
        assert palette.key?(key), "#{name} is missing the :#{key} key"
      end
    end
  end
end
