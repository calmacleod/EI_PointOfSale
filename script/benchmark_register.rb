# frozen_string_literal: true

require "json"
raise "Use only the test database" unless Rails.env.test?

samples = lambda do |&work|
  3.times { work.call }
  measurements = 20.times.map do
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    ActiveRecord::Base.uncached { work.call }
    (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000
  end.sort
  { median_ms: ((measurements[9] + measurements[10]) / 2).round(2), p95_ms: measurements[18].round(2) }
end
ActiveRecord::Base.transaction do
  prefix = "Registerbench#{Process.pid}"
  needle = "Lookupneedle#{Process.pid}"
  Customer.insert_all!(20_000.times.map { |i| { name: "#{prefix} person #{i}", email: "#{prefix}#{i}@example.test", phone: "416-555-#{i.to_s.rjust(5, '0')}" } })
  Customer.insert_all!([ { name: needle, email: "#{needle}@example.test" } ])
  Product.insert_all!(20_000.times.map { |i| { name: "#{prefix} item #{i}", code: "#{prefix}-#{i}", selling_price: 10 } })
  Service.insert_all!(2_000.times.map { |i| { name: "#{prefix} service #{i}", code: "#{prefix}-SVC-#{i}", price: 12 } })
  Product.insert_all!([ { name: needle, code: "#{prefix}-TARGET", selling_price: 10 } ])
  connection = ActiveRecord::Base.connection
  %w[index_customers_on_search_vector index_customers_on_name_trigram index_products_on_search_vector index_services_on_register_search].each do |index|
    connection.execute("SELECT gin_clean_pending_list('#{index}')")
  end
  %w[customers products services].each { |table| connection.execute("ANALYZE #{table}") }
  output = { synthetic_rows: { customers: 20_001, products: 20_001, services: 2_000 } }
  output[:legacy_customer_search] = samples.call { Customer.kept.search(needle).includes(:tax_code).limit(15).to_a }
  output[:indexed_customer_search] = samples.call { Registers::Lookup.customers(needle).includes(:tax_code).limit(15).to_a }
  output[:register_item_search] = samples.call { Registers::Lookup.items(needle) }
  output[:indexed_exact_code] = samples.call { Product.find_by_exact_code("#{prefix}-TARGET") }
  output[:exact_code_plan] = connection.select_values("EXPLAIN #{Product.kept.where("lower(code) = lower(?)", "#{prefix}-TARGET").order(:id).limit(1).to_sql}")
  output[:customer_query_plan] = connection.select_values("EXPLAIN #{Registers::Lookup.customers(needle).limit(15).to_sql}")
  puts JSON.pretty_generate(output)
  raise ActiveRecord::Rollback
end
