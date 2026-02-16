# frozen_string_literal: true

module ShopifySync
  class SyncInventoryJob < ApplicationJob
    queue_as :default

    def perform(product_id = nil)
      product = product_id ? Product.find_by(id: product_id) : nil
      ShopifySync::InventorySyncer.new.call(product)
    rescue => e
      Rails.logger.error("ShopifySync::SyncInventoryJob failed: #{e.message}")
      raise
    end
  end
end
