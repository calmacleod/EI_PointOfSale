# frozen_string_literal: true

# Patches the ruby_wasm build process for WASM compilation of this app.
#
# psych is a Ruby built-in extension that requires libyaml for linking.
# When building for WASM with Ruby 4.0, the libyaml linking fails during
# make install. Since YAML parsing is not needed for the order calculation
# WASM module, we patch ALL_DEFAULT_EXTS to remove psych before the build.
#
# This patch only activates when ruby_wasm is loaded (during WASM builds).
namespace :wasmify do
  namespace :build do
    task :core do
      if defined?(RubyWasm::Packager::ALL_DEFAULT_EXTS)
        patched = RubyWasm::Packager::ALL_DEFAULT_EXTS
          .split(",")
          .reject { |e| e == "psych" }
          .join(",")
        RubyWasm::Packager.send(:remove_const, :ALL_DEFAULT_EXTS)
        RubyWasm::Packager.const_set(:ALL_DEFAULT_EXTS, patched)
      end
    end
  end
end
