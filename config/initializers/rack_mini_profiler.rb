# frozen_string_literal: true

# Rack::MiniProfiler configuration for development
# Provides request profiling with timing, SQL, and memory analysis
# Access via the floating badge on the top-left corner of pages
#
# Shortcuts:
#   ?pp=help         - Show all options
#   ?pp=disable      - Disable for this session
#   ?pp=enable       - Enable for this session
#   ?pp=profile-gc   - Profile garbage collection
#   ?pp=profile      - CPU flamegraph (requires stackprof gem)

if Rails.env.development?
  require "rack-mini-profiler"

  # Ensure profiler is enabled
  Rack::MiniProfiler.config.enabled = true
  Rack::MiniProfiler.config.start_hidden = ENV["MINI_PROFILER_HIDE"].present?

  # Storage - use memory for single-process dev server
  Rack::MiniProfiler.config.storage = Rack::MiniProfiler::MemoryStore

  # Support Turbo navigation (prevents badge from disappearing on page transitions)
  Rack::MiniProfiler.config.enable_hotwire_turbo_drive_support = true

  # Customize the badge position
  Rack::MiniProfiler.config.position = "top-left"

  # Skip asset requests and health checks
  Rack::MiniProfiler.config.skip_paths = [
    "/assets/",
    "/packs/",
    "/up" # Rails health check
  ]

  # Authorization - allow all in development
  Rack::MiniProfiler.config.authorization_mode = :allow_all
end
