# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

require_relative "config/application"

Rails.application.load_tasks

# Patch for wasmify WASM build: remove psych from Ruby's built-in extensions.
# psych requires libyaml which doesn't link correctly in the WASM target for Ruby 4.0.
# Psych is not needed for the order calculation WASM module.
if defined?(RubyWasm::Packager) && defined?(RubyWasm::Packager::ALL_DEFAULT_EXTS)
  patched_exts = RubyWasm::Packager::ALL_DEFAULT_EXTS
    .split(",")
    .reject { |e| e == "psych" }
    .join(",")
  RubyWasm::Packager.send(:remove_const, :ALL_DEFAULT_EXTS)
  RubyWasm::Packager.const_set(:ALL_DEFAULT_EXTS, patched_exts)
end
