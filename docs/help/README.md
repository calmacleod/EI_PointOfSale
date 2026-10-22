# In-app help guide

Each `.yml` file in this directory is one document at `/help/:slug`, where the slug is the filename. The searchable guide and contextual Help links use the same documents. Content is shipped with the application and needs no database setup.

Documents use `title`, `summary`, `category`, `position`, `feature`, `keywords`, `related`, and `sections`. Set `audience: admin` for administrator-only documents; all other documents are available to signed-in staff. Related links are filtered to the reader's visible documents.

Each section has a unique `id`, a `title`, and at least one of `paragraphs`, `steps`, `bullets`, or `note`. These are plain text, rendered as escaped Svelte text. Use steps for a sequence, bullets for parallel behavior, and a note for a consequence the reader should check before acting. No HTML or Markdown renderer is required.

Use the labels and behavior of the current application. Verify workflows against the owning controller, service, and screen. Explain when work is only queued, when data changes, which actions need an administrator, and whether an action records an external payment or actually moves money. Do not promise a workflow that the screen does not offer.

Add new feature-path helpers and controller-to-document mappings to `Help::Guide`. Context mapping reads only the constant map; it does not load the help documents on ordinary register requests. Documents are cached in production, re-read during development, and searched locally on the help screen without a request per keystroke.

Run `bin/rails test test/services/help/guide_test.rb test/controllers/help_controller_test.rb`, `bin/rails test test/system/help_test.rb`, `bin/steep check`, and `npm run lint:svelte` when changing the guide or its integration.
