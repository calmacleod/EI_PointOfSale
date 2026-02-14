require "test_helper"

class TaxCodeTest < ActiveSupport::TestCase
  test "discards and undiscards" do
    tax_code = tax_codes(:one)
    assert tax_code.kept?
    tax_code.discard
    assert tax_code.discarded?
    tax_code.undiscard
    assert tax_code.kept?
  end

  test "kept scope excludes discarded" do
    tax_codes(:one).discard
    assert_not_includes TaxCode.kept, tax_codes(:one)
    assert_includes TaxCode.discarded, tax_codes(:one)
  end
end
