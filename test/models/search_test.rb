require "test_helper"

class SearchTest < ActiveSupport::TestCase
  parallelize(workers: 1)

  test "Product.search finds products by name" do
    product = Product.create!(name: "Unique Searchable Widget")
    assert_includes Product.search("Widget"), product
    assert_includes Product.search("Unique"), product
    assert_includes Product.search("Searchable"), product
    # Prefix search: partial word matches
    assert_includes Product.search("Uniq"), product
    assert_includes Product.search("Widg"), product
  end

  test "Product.search returns nothing for non-matching query" do
    Product.create!(name: "Unique Searchable Widget")
    assert_empty Product.search("nonexistent")
  end

  test "Product.search excludes discarded products" do
    product = Product.create!(name: "Discarded Soon Widget")
    assert_includes Product.kept.search("Widget"), product

    product.discard
    assert_not_includes Product.kept.search("Widget"), product
    assert_includes Product.unscoped.search("Widget"), product
  end

  test "User.search finds users by name and email" do
    # Create a new user (avoids fixture/transaction visibility issues with pg_search subqueries)
    user = User.create!(
      name: "Qwerty Searchable User",
      email_address: "qwerty.search.test@example.com",
      password: "password123!"
    )
    assert_includes User.search("Qwerty"), user
    assert_includes User.search("Searchable"), user
    assert_includes User.search("qwerty.search"), user
  end

  test "Category.search finds categories by name" do
    category = Category.create!(name: "Unique Test Category")
    assert_includes Category.search("Unique"), category
    assert_includes Category.search("Test"), category
    assert_includes Category.search("Category"), category
    assert_includes Category.search("Unique Test"), category
  end

  test "Category.search excludes discarded categories" do
    category = Category.create!(name: "Discarded Category")
    assert_includes Category.kept.search("Discarded"), category

    category.discard
    assert_not_includes Category.kept.search("Discarded"), category
  end

  test "Supplier.search finds suppliers by name and phone" do
    supplier = Supplier.create!(name: "Acme Searchable Supply", phone: "555-123-4567")
    assert_includes Supplier.search("Acme"), supplier
    assert_includes Supplier.search("Searchable"), supplier
    assert_includes Supplier.search("555-123"), supplier
  end

  test "Service.search finds services by name, code, and description" do
    service = Service.create!(
      name: "Premium Searchable Service",
      code: "SRV-SEARCH-001",
      description: "A service for testing search functionality",
      price: 1.00
    )
    assert_includes Service.search("Premium"), service
    assert_includes Service.search("SRV-SEARCH"), service
    assert_includes Service.search("testing search"), service
  end

  test "ProductVariant.search finds variants by name, code, and notes" do
    product = products(:dragon_shield)
    variant = ProductVariant.create!(
      product: product,
      code: "SRCH-VAR-999",
      name: "Searchable Variant",
      notes: "Test notes for search"
    )
    assert_includes ProductVariant.search("SRCH-VAR"), variant
    assert_includes ProductVariant.search("Searchable"), variant
    assert_includes ProductVariant.search("Test notes"), variant
  end

  test "TaxCode.search finds tax codes by code, name, and notes" do
    tax_code = TaxCode.create!(code: "SRCH-TAX", name: "Searchable Tax", notes: "Test tax notes")
    assert_includes TaxCode.search("SRCH-TAX"), tax_code
    assert_includes TaxCode.search("Searchable"), tax_code
    assert_includes TaxCode.search("Test tax"), tax_code
  end

  test "PgSearch.multisearch finds records across models" do
    product = Product.create!(name: "Multisearch Widget")
    user = User.create!(
      name: "Multisearch User",
      email_address: "multisearch@example.com",
      password: "password123!"
    )
    category = Category.create!(name: "Multisearch Category")

    results = PgSearch.multisearch("Multisearch")
    searchables = results.map(&:searchable)

    assert_includes searchables, product
    assert_includes searchables, user
    assert_includes searchables, category
  end

  test "PgSearch.multisearch returns PgSearch::Document with searchable association" do
    product = Product.create!(name: "Document Test Product")
    results = PgSearch.multisearch("Document Test")
    assert results.any?
    doc = results.first
    assert_instance_of PgSearch::Document, doc
    assert_equal product, doc.searchable
  end

  test "PgSearch.multisearch excludes discarded records from Discard models" do
    product = Product.create!(name: "Multisearch Discardable")
    assert PgSearch.multisearch("Discardable").any? { |d| d.searchable == product }

    product.discard
    assert_empty PgSearch.multisearch("Discardable").select { |d| d.searchable == product }
  end
end
