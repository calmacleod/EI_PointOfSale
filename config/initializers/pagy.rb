# frozen_string_literal: true

# Pagy initializer
# See https://ddnexus.github.io/pagy/resources/initializer/

Pagy::OPTIONS[:limit] = 25
Pagy::OPTIONS[:client_limit] = 100

Rails.application.config.assets.paths << Pagy::ROOT.join("stylesheets")
