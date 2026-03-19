# frozen_string_literal: true

module Products
  class RestockService
    Result = Struct.new(:success?, :restock, :errors, keyword_init: true)

    def self.call(product:, quantity:, user:, notes: nil)
      new(product: product, quantity: quantity, user: user, notes: notes).call
    end

    def initialize(product:, quantity:, user:, notes: nil)
      @product = product
      @quantity = quantity.to_i
      @user = user
      @notes = notes
    end

    def call
      if @quantity <= 0
        return Result.new(success?: false, restock: nil, errors: [ "Quantity must be greater than 0" ])
      end

      restock = nil

      @product.transaction do
        @product.lock!
        new_stock = @product.stock_level + @quantity
        @product.update!(stock_level: new_stock)

        restock = @product.restocks.create!(
          user: @user,
          quantity: @quantity,
          stock_level_after: new_stock,
          notes: @notes
        )
      end

      Result.new(success?: true, restock: restock, errors: [])
    rescue => e
      Result.new(success?: false, restock: nil, errors: [ e.message ])
    end
  end
end
