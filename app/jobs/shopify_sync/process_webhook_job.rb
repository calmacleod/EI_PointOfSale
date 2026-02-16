# frozen_string_literal: true

module ShopifySync
  class ProcessWebhookJob < ApplicationJob
    queue_as :default

    def perform(topic:, payload:)
      ShopifySync::WebhookHandler.new.call(topic: topic, payload: payload)
    rescue => e
      Rails.logger.error("ShopifySync::ProcessWebhookJob failed for #{topic}: #{e.message}")
      raise
    end
  end
end
