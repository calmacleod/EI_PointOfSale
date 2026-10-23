# frozen_string_literal: true

module Registers
  # Search the live catalog directly: no delayed multisearch jobs or full catalog downloads.
  class Lookup
    LIMIT = 12
    SERVICE_VECTOR = "to_tsvector('simple', coalesce(name, '') || ' ' || coalesce(code, '') || ' ' || coalesce(description, ''))"
    CUSTOMER_VECTOR = "customers.search_vector"
    # Let PostgreSQL tokenize emails, hyphenated SKUs, and punctuation, then prefix
    # every lexeme. quote_literal keeps tsquery operators in user input harmless.
    PREFIX_QUERY = "(SELECT to_tsquery('simple', string_agg(quote_literal(word) || ':*', ' & ')) FROM unnest(tsvector_to_array(to_tsvector('simple', :query))) AS word)"

    def self.items(raw_query)
      query = raw_query.to_s.strip.first(160)
      results = item_matches(Product, :selling_price, query) + item_matches(Service, :price, query)

      results.sort_by do |result|
        [ query.present? && result[:code].to_s.casecmp?(query) ? 0 : 1, -result[:rank], -result[:sales_count].to_i, result[:type], result[:id] ]
      end.first(LIMIT).map { |result| result.except(:rank, :sales_count) }
    end

    def self.item_matches(model, price_column, query)
      vector = model == Product ? "search_vector" : SERVICE_VECTOR
      scope = model.kept
      relevance = "0"
      if query.present?
        scope = scope.where("lower(code) = lower(:query) OR #{vector} @@ #{PREFIX_QUERY}", query: query)
        relevance = model.sanitize_sql_array([ "ts_rank(#{vector}, #{PREFIX_QUERY})", { query: query } ])
        ranking = model.sanitize_sql_array([ "CASE WHEN lower(code) = lower(:query) THEN 1 ELSE 0 END DESC, ts_rank(#{vector}, #{PREFIX_QUERY}) DESC", { query: query } ])
        scope = scope.order(Arel.sql(ranking))
      end
      scope.order(sales_count: :desc, id: :asc).limit(LIMIT).pluck(:id, :name, :code, price_column, :sales_count, Arel.sql(relevance)).map do |id, name, code, price, sales_count, rank|
        { id: id, type: model.name, name: name, code: code, price: price.to_s, sales_count: sales_count, rank: rank.to_f }
      end
    end
    private_class_method :item_matches

    def self.customers(raw_query)
      query = raw_query.to_s.strip.first(160)
      return Customer.none if query.blank?

      # The % operator uses the trigram index; similarity(...) > threshold cannot.
      ranking = Customer.sanitize_sql_array([ "ts_rank(#{CUSTOMER_VECTOR}, #{PREFIX_QUERY}) DESC, similarity(lower(name), lower(:query)) DESC", { query: query } ])
      Customer.kept.where("#{CUSTOMER_VECTOR} @@ #{PREFIX_QUERY} OR lower(name) % lower(:query)", query: query)
        .order(Arel.sql(ranking)).order(:name, :id)
    end
  end
end
