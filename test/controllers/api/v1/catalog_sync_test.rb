require "test_helper"

class Api::V1::CatalogSyncTest < ActionDispatch::IntegrationTest
  setup { sign_in_as(users(:one)) }

  test "every catalog can be consumed in bounded stable pages by common users" do
    [ Product, Service, Customer, TaxCode ].each do |model|
      collection = model.table_name
      path = "/api/v1/#{collection}/sync"
      params = { page_size: 1 }
      ids = []
      boundaries = []
      loop do
        get path, params: params, as: :json
        assert_response :success
        body = response.parsed_body
        assert_operator body.fetch(collection).size + body.fetch("deleted_ids").size, :<=, 1
        ids.concat(body.fetch(collection).pluck("id"))
        boundaries << body.fetch("synced_at")
        assert_equal ids.uniq, ids, "A page repeated a record"
        break unless body["next_cursor"]
        params[:cursor] = body["next_cursor"]
      end
      assert_equal model.kept.order(:updated_at, :id).pluck(:id), ids
      assert_equal 1, boundaries.uniq.size
    end
  end

  test "page size is capped and tied timestamps do not skip records" do
    Customer.insert_all!(501.times.map { |i| { name: "Sync #{i}", updated_at: 1.day.ago.change(usec: 0) } })
    get api_v1_customers_sync_path, params: { page_size: 100_000 }, as: :json
    assert_response :success
    body = response.parsed_body
    assert_equal 500, body.fetch("customers").size
    assert body["next_cursor"].present?
    ids = body.fetch("customers").pluck("id")
    get api_v1_customers_sync_path, params: { cursor: body["next_cursor"] }, as: :json
    assert_response :success
    ids.concat(response.parsed_body.fetch("customers").pluck("id"))
    assert_equal Customer.kept.order(:updated_at, :id).pluck(:id), ids
    assert_nil response.parsed_body["next_cursor"]
  end

  test "delta pages bound deletions too and retain microsecond timestamps" do
    since = 1.hour.ago.change(usec: 123456)
    Customer.update_all(updated_at: since, discarded_at: since)
    expected = Customer.order(:id).pluck(:id)
    ids = []
    params = { page_size: 1, since: since.iso8601(6) }
    loop do
      get api_v1_customers_sync_path, params: params, as: :json
      assert_response :success
      body = response.parsed_body
      assert_empty body.fetch("customers")
      assert_equal 1, body.fetch("deleted_ids").length
      ids.concat(body.fetch("deleted_ids"))
      assert_equal ids.uniq, ids, "A page repeated a deletion"
      break unless body["next_cursor"]
      params[:cursor] = body["next_cursor"]
    end
    assert_equal expected, ids
  end

  test "updates and deletions during a full sync are recovered by the next delta" do
    boundary = Time.current.change(usec: 123456)
    Customer.update_all(updated_at: 1.day.ago)
    first, second = Customer.kept.order(:updated_at, :id).first(2)
    cursor = nil
    travel_to boundary, with_usec: true do
      get api_v1_customers_sync_path, params: { page_size: 1 }, as: :json
      assert_equal first.id, response.parsed_body.fetch("customers").first.fetch("id")
      cursor = response.parsed_body.fetch("next_cursor")
    end
    travel_to boundary + 1.second, with_usec: true do
      first.discard!
      second.update!(name: "Changed during paging")
      get api_v1_customers_sync_path, params: { cursor: cursor }, as: :json
      assert_response :success
      assert_equal boundary.iso8601(6), response.parsed_body.fetch("synced_at")
      assert_not_includes response.parsed_body.fetch("customers").pluck("id"), second.id

      get api_v1_customers_sync_path, params: { page_size: 500, since: boundary.iso8601(6) }, as: :json
      assert_response :success
      assert_includes response.parsed_body.fetch("deleted_ids"), first.id
      assert_includes response.parsed_body.fetch("customers").pluck("id"), second.id
    end
  end

  test "cursor cannot be modified reused for another collection or used after expiry" do
    get api_v1_customers_sync_path, params: { page_size: 1 }, as: :json
    cursor = response.parsed_body.fetch("next_cursor")
    get api_v1_customers_sync_path, params: { cursor: "#{cursor}tampered" }, as: :json
    assert_response :bad_request
    get api_v1_products_sync_path, params: { cursor: cursor }, as: :json
    assert_response :bad_request
    travel 2.hours do
      get api_v1_customers_sync_path, params: { cursor: cursor }, as: :json
      assert_response :bad_request
    end
  end

  test "cursor retries return the same page and ignore changed client bounds" do
    get api_v1_customers_sync_path, params: { page_size: 1 }, as: :json
    cursor = response.parsed_body.fetch("next_cursor")
    get api_v1_customers_sync_path, params: { cursor: cursor }, as: :json
    expected = response.parsed_body.except("next_cursor")
    get api_v1_customers_sync_path, params: { cursor: cursor, since: 1.year.from_now.iso8601, page_size: 10_000 }, as: :json
    assert_response :success
    assert_equal expected, response.parsed_body.except("next_cursor")
  end

  test "sync never instantiates catalog or association models" do
    instantiated = []
    subscriber = ->(event) { instantiated << event.payload[:class_name] }
    ActiveSupport::Notifications.subscribed(subscriber, "instantiation.active_record") do
      [ Product, Service, Customer, TaxCode ].each do |model|
        get "/api/v1/#{model.table_name}/sync", params: { page_size: 500 }, as: :json
        assert_response :success
      end
    end
    assert_empty instantiated & %w[Product Service Customer TaxCode Supplier ProductGroup]
  end

  test "scalar product serialization preserves nullable decimals timestamps and discarded associations" do
    product = products(:dragon_shield_red)
    product.update!(purchase_price: nil, unit_cost: BigDecimal("0.125"), last_restocked_at: 2.days.ago)
    product.tax_code.discard!
    product.reload
    expected = {
      "id" => product.id, "code" => product.code, "name" => product.name,
      "selling_price" => product.selling_price.to_s, "purchase_price" => nil,
      "stock_level" => product.stock_level, "reorder_level" => product.reorder_level, "order_quantity" => product.order_quantity,
      "unit_cost" => product.unit_cost.to_s, "items_per_unit" => product.items_per_unit,
      "supplier_reference" => product.supplier_reference, "notes" => product.notes, "product_url" => product.product_url,
      "tax_code" => product.tax_code.code, "tax_rate" => product.tax_code.rate.to_s,
      "supplier" => product.supplier&.name, "product_group" => product.product_group&.name,
      "sync_to_shopify" => product.sync_to_shopify, "sales_count" => product.sales_count,
      "last_restocked_at" => product.last_restocked_at.iso8601,
      "created_at" => product.created_at.iso8601, "updated_at" => product.updated_at.iso8601
    }
    [ {}, { page_size: 500 } ].each do |params|
      get api_v1_products_sync_path, params: params, as: :json
      assert_response :success
      assert_equal expected, response.parsed_body.fetch("products").find { |row| row["id"] == product.id }
    end

    product.update!(tax_code: nil, supplier: nil, product_group: nil, last_restocked_at: nil)
    get api_v1_products_sync_path, params: { page_size: 500 }, as: :json
    row = response.parsed_body.fetch("products").find { |data| data["id"] == product.id }
    %w[tax_code tax_rate supplier product_group last_restocked_at].each { |key| assert_nil row.fetch(key) }
  end

  test "timestamp indexes support both kept and discarded delta scans" do
    connection = ActiveRecord::Base.connection
    connection.execute("SET LOCAL enable_seqscan = off")
    [ Product, Service, Customer, TaxCode ].each do |model|
      model.insert_all!(2_000.times.map do |i|
        row = { name: "Index sample #{i}", updated_at: 1.day.ago, discarded_at: i.even? ? 1.day.ago : nil }
        row[:code] = "SYNC-INDEX-#{i}" unless model == Customer
        row[:price] = 1 if model == Service
        row
      end)
      connection.execute("ANALYZE #{model.table_name}")
      [ model.kept, model.discarded ].each do |scope|
        sql = scope.where("updated_at >= ?", Time.current).order(:updated_at, :id).limit(500).to_sql
        plan = connection.select_values("EXPLAIN #{sql}").join("\n")
        assert_includes plan, "index_#{model.table_name}_on_updated_at_and_id"
      end
    end
  end
end
