# frozen_string_literal: true

# RAILS_ENV=test bin/rails runner script/benchmark_api.rb
# Use a dedicated, migrated test database, separately from the test suite.
# All synthetic records are rolled back. See docs/rails-performance.md.
require "json"
require "action_dispatch/testing/integration"
require "action_dispatch/testing/test_request"

raise "Use only the test database" unless Rails.env.test?

module ApiBenchmark
  module_function

  def clock
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end

  def percentile(values, fraction)
    values.sort.fetch((values.length * fraction).ceil - 1).round(3)
  end

  def rss_mb
    kb = if File.exist?("/proc/self/status")
      File.read("/proc/self/status")[/^VmRSS:\s+(\d+)/, 1].to_i
    else
      `ps -o rss= -p #{Process.pid}`.to_i
    end
    kb.fdiv(1024).round(1)
  end

  def measure(client, path, params:, headers:, key:, warmup:, samples:, method: :get, rollback: false, all_pages: false)
    page_count = response_bytes = largest_page_bytes = result_count = nil
    perform_request = lambda do
      page_params = params.dup
      page_count = response_bytes = largest_page_bytes = result_count = 0
      boundary = nil
      loop do
        ActiveRecord::Base.connection_pool.clear_query_cache
        client.public_send(method, path, params: page_params, headers: headers)
        raise "#{path}: HTTP #{client.response.status}" unless client.response.status == 200
        page_count += 1
        response_bytes += client.response.body.bytesize
        largest_page_bytes = [ largest_page_bytes, client.response.body.bytesize ].max
        break unless all_pages
        body = client.response.parsed_body
        result_count += body.fetch(key).size
        raise "Sync boundary changed" if boundary && boundary != body.fetch("synced_at")
        boundary = body.fetch("synced_at")
        break unless body["next_cursor"]
        raise "Paging did not finish" if page_count > 1_000
        page_params[:cursor] = body.fetch("next_cursor")
      end
    end
    request = lambda do
      if rollback
        ActiveRecord::Base.transaction(requires_new: true) do
          perform_request.call
          raise ActiveRecord::Rollback
        end
      else
        perform_request.call
      end
    end
    started = clock
    request.call
    cold_ms = (clock - started) * 1000
    body = client.response.parsed_body
    raise "#{path}: missing #{key}" unless body.key?(key)
    first_result_count = all_pages ? result_count : (body[key].is_a?(Array) ? body[key].size : nil)
    if all_pages
      expected_count = key.classify.constantize.kept.count
      raise "Incomplete sync: #{first_result_count}/#{expected_count}" unless first_result_count == expected_count
    end
    warmup.times { request.call }

    sql = []
    instantiated = 0
    sql_subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |event|
      next if event.payload[:name].in?(%w[SCHEMA TRANSACTION]) || event.payload[:cached]
      sql << { sql: event.payload[:sql], ms: event.duration.round(3) }
    end
    instantiation_subscriber = ActiveSupport::Notifications.subscribe("instantiation.active_record") do |event|
      instantiated += event.payload[:record_count]
    end
    begin
      request.call
    ensure
      ActiveSupport::Notifications.unsubscribe(sql_subscriber)
      ActiveSupport::Notifications.unsubscribe(instantiation_subscriber)
    end

    allocated = []
    gc_before = GC.stat
    cpu_before = Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID)
    times = samples.times.map do
      objects_before = GC.stat(:total_allocated_objects)
      started = clock
      request.call
      elapsed = (clock - started) * 1000
      allocated << GC.stat(:total_allocated_objects) - objects_before
      elapsed
    end
    cpu_ms = (Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID) - cpu_before) * 1000
    {
      path: path, method: method, params: params, all_pages: all_pages, rollback_each_request: rollback, warmup: warmup, samples: samples,
      first_request_ms: cold_ms.round(3), median_ms: percentile(times, 0.5),
      p95_ms: percentile(times, 0.95), mean_ms: (times.sum / samples).round(3),
      cpu_ms_per_request: (cpu_ms / samples).round(3),
      allocated_objects_per_request: (allocated.sum / samples.to_f).round,
      gc_ms: GC.stat(:time) - gc_before[:time], rss_mb: rss_mb,
      response_bytes: response_bytes, largest_page_bytes: largest_page_bytes, page_count: page_count, result_count: first_result_count,
      sql_count: sql.size, sql_ms: sql.sum { |query| query[:ms] }.round(3),
      instantiated_records: instantiated, sql: sql
    }
  end
end

Rails.application.eager_load!
Rails.logger.level = Logger::ERROR
Rails.cache = ActiveSupport::Cache::MemoryStore.new
ActiveJob::Base.queue_adapter = :test

jit = if defined?(RubyVM::ZJIT) && RubyVM::ZJIT.enabled?
  "zjit"
elsif RubyVM::YJIT.enabled?
  "yjit"
else
  "interpreter"
end
raise "Expected #{ENV['EXPECTED_JIT']}, got #{jit}" if ENV["EXPECTED_JIT"] && ENV["EXPECTED_JIT"] != jit

products_count = Integer(ENV.fetch("BENCH_PRODUCTS", 20_000))
customers_count = Integer(ENV.fetch("BENCH_CUSTOMERS", 20_000))
services_count = Integer(ENV.fetch("BENCH_SERVICES", 2_000))
warmup = Integer(ENV.fetch("BENCH_WARMUP", 200))
samples = Integer(ENV.fetch("BENCH_SAMPLES", 300))
bulk_warmup = Integer(ENV.fetch("BENCH_BULK_WARMUP", 3))
bulk_samples = Integer(ENV.fetch("BENCH_BULK_SAMPLES", 10))
slow_warmup = Integer(ENV.fetch("BENCH_SLOW_WARMUP", 20))
slow_samples = Integer(ENV.fetch("BENCH_SLOW_SAMPLES", 50))
raise "Counts and samples must be positive" unless [ products_count, customers_count, services_count, samples, slow_samples, bulk_samples ].all?(&:positive?)
raise "Warm-up counts must not be negative" unless [ warmup, slow_warmup, bulk_warmup ].none?(&:negative?)

output = {
  ruby: RUBY_DESCRIPTION, jit: jit, platform: RUBY_PLATFORM,
  measured_at: Time.current.iso8601, environment: Rails.env,
  cache: Rails.cache.class.name, synthetic_rows: { products: products_count, customers: customers_count, services: services_count },
  endpoints: {}
}

ActiveRecord::Base.transaction do
  old_timestamp = 2.days.ago
  tax = TaxCode.create!(code: "API-AUDIT", name: "Audit tax", rate: 0.13)
  supplier = Supplier.create!(name: "Audit supplier")
  group = ProductGroup.create!(name: "Audit group")
  admin = Admin.create!(name: "API audit", email_address: "api-audit@example.test", password: "benchmark-only-password")
  product_ids = Product.insert_all!(Array.new(products_count) do |i|
    { name: i.zero? ? "Needle product" : "Audit product #{i}", code: "API-AUDIT-#{i}",
      selling_price: 12.99, purchase_price: 5.25, stock_level: 20, sales_count: i % 100,
      tax_code_id: tax.id, supplier_id: supplier.id, product_group_id: group.id,
      created_at: old_timestamp, updated_at: old_timestamp }
  end).rows.flatten
  Customer.insert_all!(Array.new(customers_count) do |i|
    { name: i.zero? ? "Needle customer" : "Audit customer #{i}", email: "api-audit-#{i}@example.test",
      phone: "416-555-#{i.to_s.rjust(5, '0')}", member_number: "AUDIT-#{i}", tax_code_id: tax.id,
      created_at: old_timestamp, updated_at: old_timestamp }
  end)
  Service.insert_all!(Array.new(services_count) do |i|
    { name: "Audit service #{i}", code: "API-AUDIT-SVC-#{i}", price: 20,
      tax_code_id: tax.id, sales_count: i % 10, created_at: old_timestamp, updated_at: old_timestamp }
  end)
  PgSearch::Document.insert_all!(product_ids.each_with_index.map do |id, i|
    { searchable_type: "Product", searchable_id: id,
      content: "#{i.zero? ? 'Needle' : 'Audit'} product #{i} API-AUDIT-#{i}" }
  end)
  order = Order.create!(created_by: admin)
  Product.where(id: product_ids.first(12)).each_with_index do |product, index|
    line = order.order_lines.build(quantity: 1, position: index + 1)
    line.snapshot_from_sellable!(product)
    line.save!
  end
  Orders::CalculateTotals.call(order)

  connection = ActiveRecord::Base.connection
  %w[products customers services pg_search_documents].each { |table| connection.execute("ANALYZE #{table}") }
  %w[index_products_on_search_vector index_customers_on_search_vector index_customers_on_name_trigram index_services_on_register_search index_pg_search_documents_on_content_tsv index_pg_search_documents_on_content_trgm].each do |index|
    connection.execute("SELECT gin_clean_pending_list('#{index}')")
  end

  client = ActionDispatch::Integration::Session.new(Rails.application)
  cookie_jar = ActionDispatch::TestRequest.create.cookie_jar
  cookie_jar.signed[:session_id] = admin.sessions.create!.id
  client.cookies["session_id"] = cookie_jar[:session_id]
  json_headers = { "Accept" => "application/json" }
  inertia_headers = { "Accept" => "text/html", "X-Inertia" => "true", "X-Inertia-Version" => InertiaRails.configuration.version }
  cases = {
    register_popular: [ "/register/lookup", {} ],
    register_exact: [ "/register/lookup", { q: "API-AUDIT-0" } ],
    register_search: [ "/register/lookup", { q: "Needle" } ],
    register_broad_search: [ "/register/lookup", { q: "Audit" } ],
    customer_search: [ "/customers/search", { q: "Needle" } ],
    customer_broad_search: [ "/customers/search", { q: "Audit" } ],
    inventory_lookup: [ "/inventory/lookup", { code: "API-AUDIT-0" }, "found" ],
    global_search: [ "/search", { q: "Needle" } ],
    product_page: [ "/products", {}, "props", inertia_headers ],
    register_page: [ "/register", { order_id: order.id }, "props", inertia_headers ],
    products_delta: [ "/api/v1/products/sync", { since: 1.day.ago.iso8601, page_size: 500 }, "products" ],
    customers_delta: [ "/api/v1/customers/sync", { since: 1.day.ago.iso8601, page_size: 500 }, "customers" ],
    products_full: [ "/api/v1/products/sync", {}, "products", json_headers, true ],
    customers_full: [ "/api/v1/customers/sync", {}, "customers", json_headers, true ],
    services_full: [ "/api/v1/services/sync", {}, "services", json_headers, true ],
    products_page: [ "/api/v1/products/sync", { page_size: 500 }, "products", json_headers, true ],
    customers_page: [ "/api/v1/customers/sync", { page_size: 500 }, "customers", json_headers, true ],
    products_paged: [ "/api/v1/products/sync", { page_size: 500 }, "products", json_headers, true ],
    customers_paged: [ "/api/v1/customers/sync", { page_size: 500 }, "customers", json_headers, true ]
  }
  if ENV["BENCH_WRITES"] == "1"
    cases[:scan_12_lines] = [ "/orders/quick_lookup", { order_id: order.id, code: "API-AUDIT-0" }, "order" ]
  end
  selected = ENV["BENCH_CASES"]&.split(",")
  if selected && (selected & cases.keys.map(&:to_s)).empty?
    raise "BENCH_CASES does not select a known endpoint"
  end
  GC.start
  output[:rss_before_requests_mb] = ApiBenchmark.rss_mb
  cases.each do |name, (path, params, key, headers, bulk)|
    next if selected && !selected.include?(name.to_s)
    case_warmup, case_samples = if bulk
      [ bulk_warmup, bulk_samples ]
    elsif name == :customer_broad_search
      [ slow_warmup, slow_samples ]
    else
      [ warmup, samples ]
    end
    output[:endpoints][name] = ApiBenchmark.measure(client, path,
      params: params, headers: headers || json_headers, key: key || "results",
      warmup: case_warmup, samples: case_samples,
      method: name == :scan_12_lines ? :post : :get, rollback: name == :scan_12_lines,
      all_pages: name.to_s.end_with?("_paged"))
    warn "#{jit} #{name}: #{output[:endpoints][name][:median_ms]} ms median"
  end
  output[:rss_mb] = ApiBenchmark.rss_mb
  output[:jit_stats] = if jit == "yjit"
    RubyVM::YJIT.runtime_stats
  elsif jit == "zjit"
    RubyVM::ZJIT.stats
  end
  raise ActiveRecord::Rollback
end

if ENV["BENCH_OUTPUT"]
  File.write(ENV.fetch("BENCH_OUTPUT"), JSON.pretty_generate(output) + "\n")
else
  puts JSON.pretty_generate(output)
end
