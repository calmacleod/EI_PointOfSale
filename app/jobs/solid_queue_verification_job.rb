# frozen_string_literal: true

# Test job to verify Solid Queue is processing jobs.
# Enqueue from the dev tools page or Rails console.
class SolidQueueVerificationJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "[SolidQueueVerificationJob] Job ran at #{Time.current}"
  end
end
