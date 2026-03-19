# frozen_string_literal: true

module Products
  class BulkRestockService
    Result = Struct.new(:success?, :successes, :failures, keyword_init: true)

    def self.call(items:, user:)
      new(items: items, user: user).call
    end

    def initialize(items:, user:)
      @items = items
      @user = user
    end

    def call
      successes = []
      failures = []

      ActiveRecord::Base.transaction do
        @items.each do |item|
          next if item[:quantity].to_i <= 0

          product = Product.find_by(id: item[:product_id])
          unless product
            failures << { product_id: item[:product_id], errors: [ "Product not found" ] }
            next
          end

          result = RestockService.call(
            product: product,
            quantity: item[:quantity],
            user: @user,
            notes: item[:notes]
          )

          if result.success?
            successes << result.restock
          else
            failures << { product_id: item[:product_id], errors: result.errors }
            raise ActiveRecord::Rollback
          end
        end
      end

      Result.new(
        success?: failures.empty?,
        successes: successes,
        failures: failures
      )
    end
  end
end
