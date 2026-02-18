# frozen_string_literal: true

# PgSearch configuration
# Note: Async updates are handled via the AsyncPgSearch concern included in models
PgSearch.multisearch_options = {
  using: {
    tsearch: { prefix: true },
    trigram: {}
  }
}
