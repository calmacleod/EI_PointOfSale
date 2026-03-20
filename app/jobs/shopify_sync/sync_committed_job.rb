# frozen_string_literal: true

module ShopifySync
  class SyncCommittedJob < ApplicationJob
    queue_as :default

    def perform(product_id, delta)
      product = Product.find_by(id: product_id)
      return unless product

      ShopifySync::CommittedSyncer.new.call(product, delta)
    rescue => e
      Rails.logger.error("ShopifySync::SyncCommittedJob failed for product #{product_id}: #{e.message}")
      raise
    end
  end
end
