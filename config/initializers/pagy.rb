# frozen_string_literal: true

# Pagy initializer (43.2.9)
# See https://ddnexus.github.io/pagy/resources/initializer/

Pagy.options[:limit] = 25
Pagy.options[:client_max_limit] = 100

Rails.application.config.assets.paths << Pagy::ROOT.join("stylesheets")
