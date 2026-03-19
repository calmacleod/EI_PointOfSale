# frozen_string_literal: true

class RefreshSalesCountsJob < ApplicationJob
  queue_as :low

  QUALIFYING_STATUSES = %w[completed refunded partially_refunded].freeze
  WINDOW = 90.days

  def perform
    cutoff = WINDOW.ago

    %w[Product Service].each do |type|
      table = type.tableize

      update_sql = <<~SQL
        UPDATE #{table}
        SET sales_count = COALESCE(counts.total, 0)
        FROM (
          SELECT order_lines.sellable_id,
                 SUM(order_lines.quantity) AS total
          FROM order_lines
          INNER JOIN orders ON orders.id = order_lines.order_id
          WHERE order_lines.sellable_type = ?
            AND orders.status IN (?)
            AND orders.completed_at >= ?
          GROUP BY order_lines.sellable_id
        ) counts
        WHERE #{table}.id = counts.sellable_id
      SQL

      zero_sql = <<~SQL
        UPDATE #{table}
        SET sales_count = 0
        WHERE id NOT IN (
          SELECT order_lines.sellable_id
          FROM order_lines
          INNER JOIN orders ON orders.id = order_lines.order_id
          WHERE order_lines.sellable_type = ?
            AND orders.status IN (?)
            AND orders.completed_at >= ?
        )
        AND sales_count != 0
      SQL

      status_values = QUALIFYING_STATUSES.map { |s| Order.statuses[s] }

      ActiveRecord::Base.connection.execute(
        ActiveRecord::Base.sanitize_sql([ update_sql, type, status_values, cutoff ])
      )
      ActiveRecord::Base.connection.execute(
        ActiveRecord::Base.sanitize_sql([ zero_sql, type, status_values, cutoff ])
      )
    end
  end
end
