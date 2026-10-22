require "test_helper"

class Registers::LookupTest < ActiveSupport::TestCase
  test "items find word prefixes in names and hyphenated codes without multisearch jobs" do
    product = products(:dragon_shield_red)
    service = Service.create!(name: "Dragon tuning", code: "DRAGON-TUNE", price: 12)

    results = Registers::Lookup.items("drag")
    assert results.any? { |item| item[:type] == "Product" && item[:id] == product.id }
    assert results.any? { |item| item[:type] == "Service" && item[:id] == service.id }
    assert_equal product.id, Registers::Lookup.items("ds-mat-red").first[:id]
  end

  test "exact service code wins over product name matches" do
    service = Service.create!(name: "Exact service", code: "Dragon", price: 10)
    assert_equal [ "Service", service.id ], Registers::Lookup.items("dragon").first.values_at(:type, :id)
  end

  test "search excludes discarded items and returns at most twelve compact results" do
    products(:dragon_shield_red).discard!
    15.times { |i| Service.create!(name: "Dragon service #{i}", price: i) }
    results = Registers::Lookup.items("dragon")
    assert_equal 12, results.size
    assert results.none? { |item| item[:type] == "Product" && item[:id] == products(:dragon_shield_red).id }
    assert_equal %i[code id name price type], results.first.keys.sort
  end

  test "customer lookup supports prefixes email membership formatted phones and typos" do
    customer = customers(:acme_corp)
    [ "Acme", "acme@example.com", customer.member_number, "5550100", "Acne Corp" ].each do |query|
      assert_includes Registers::Lookup.customers(query).limit(15).pluck(:id), customer.id, query
    end
    customer.discard!
    assert_not_includes Registers::Lookup.customers("Acme").pluck(:id), customer.id
  end

  test "punctuation and tsquery operators are safe" do
    [ "'", "!!!", "&|:*!", "Dragon' | !shield" ].each do |query|
      assert_kind_of Array, Registers::Lookup.items(query)
      assert_kind_of Array, Registers::Lookup.customers(query).limit(15).to_a
    end
  end

  test "lookup predicates can use their matching indexes" do
    connection = ActiveRecord::Base.connection
    connection.execute("SET LOCAL enable_seqscan = off")
    product_sql = Product.kept.where("lower(code) = lower(?)", "DS-MAT-RED").order(:id).limit(1).to_sql
    assert_includes connection.select_values("EXPLAIN #{product_sql}").join("\n"), "index_products_on_kept_lower_code"

    # With a handful of fixtures the kept-record btree is legitimately cheaper.
    # Use a realistic collection so the plan exercises the selective search indexes.
    Customer.insert_all!(2_000.times.map { |i| { name: "Unrelated person #{i}", email: "person#{i}@example.com" } })
    connection.execute("SELECT gin_clean_pending_list('index_customers_on_register_search')")
    connection.execute("SELECT gin_clean_pending_list('index_customers_on_name_trigram')")
    connection.execute("ANALYZE customers")
    customer_sql = Registers::Lookup.customers("Acme").limit(15).to_sql
    plan = connection.select_values("EXPLAIN #{customer_sql}").join("\n")
    assert_includes plan, "index_customers_on_register_search"
    assert_includes plan, "index_customers_on_name_trigram"
  end
end
