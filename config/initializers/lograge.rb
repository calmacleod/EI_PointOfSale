# frozen_string_literal: true

# Lograge configuration for clean development logging
# Shows single-line request summaries with timing breakdown
# Keeps ActiveRecord query logging enabled for N+1 detection

if Rails.env.development?
  Rails.application.configure do
    config.lograge.enabled = true
    config.lograge.formatter = Lograge::Formatters::KeyValue.new

    # Add timing details to log output
    config.lograge.custom_options = lambda do |event|
      # Handle both Time objects and Float timestamps (e.g., ActionCable events)
      time_str = if event.time.is_a?(Time)
                   event.time.strftime("%H:%M:%S")
      elsif event.time.is_a?(Float)
                   Time.at(event.time).strftime("%H:%M:%S")
      else
                   event.time.to_s
      end

      data = {
        time: time_str,
        db: event.payload[:db_runtime]&.round(2),
        view: event.payload[:view_runtime]&.round(2)
      }

      # Add allocations if available (Rails 6.1+)
      if event.payload[:allocations]
        data[:allocations] = event.payload[:allocations]
      end

      data
    end

    # Ignore health checks and asset requests
    config.lograge.ignore_actions = [
      "Rails::HealthController#show"
    ]
  end

  # Silence noisy components but keep AR queries
  Rails.application.config.after_initialize do
    # Disable Action View rendering logs (very noisy)
    if defined?(ActionView::LogSubscriber)
      ActionView::LogSubscriber.detach_from(:action_view)
    end

    # Disable Active Storage logs
    if defined?(ActiveStorage::LogSubscriber)
      ActiveStorage::LogSubscriber.detach_from(:active_storage)
    end
  end
end
