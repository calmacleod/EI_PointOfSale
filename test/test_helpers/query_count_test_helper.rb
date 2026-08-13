# frozen_string_literal: true

module QueryCountTestHelper
  IGNORED_QUERY_NAMES = %w[SCHEMA TRANSACTION CACHE].freeze
  TRANSACTION_SQL = /\A(?:BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE SAVEPOINT)\b/i

  def capture_sql_queries
    queries = []
    subscriber = lambda do |_name, _started, _finished, _id, payload|
      next if payload[:cached]
      next if IGNORED_QUERY_NAMES.include?(payload[:name])

      sql = payload[:sql].to_s.squish
      queries << sql unless sql.match?(TRANSACTION_SQL)
    end

    ActiveRecord::Base.uncached do
      ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") { yield }
    end

    queries
  end

  def assert_queries_at_most(maximum, label: nil, &block)
    queries = capture_sql_queries(&block)
    message = [
      label || "Request",
      "issued #{queries.length} SQL queries; expected at most #{maximum}.",
      queries.each_with_index.map { |sql, index| "#{index + 1}. #{sql}" }
    ].join("\n")

    assert_operator queries.length, :<=, maximum, message
    queries
  end
end
