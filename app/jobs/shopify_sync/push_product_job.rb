# frozen_string_literal: true

module ShopifySync
  class PushProductJob < ApplicationJob
    queue_as :default

    def perform(product_id)
      product = Product.find_by(id: product_id)
      return unless product&.sync_to_shopify?

      ShopifySync::ProductPusher.new.call(product)
    rescue => e
      Rails.logger.error("ShopifySync::PushProductJob failed for product #{product_id}: #{e.message}")
      raise
    end
  end
end
