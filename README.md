# Ei Point of Sale

## Local CI & Signoff

Run the full CI suite locally (tests, lint, security scans) and sign off on PRs when everything passes:

```bash
bin/ci
```

When all steps pass, `gh signoff` runs automatically to set a green GitHub commit status on your PR.

### One-time setup for signoff

1. Install the [GitHub CLI](https://cli.github.com/): `brew install gh`
2. Authenticate: `gh auth login`
3. Install the signoff extension:
   ```bash
   gh extension install basecamp/gh-signoff
   ```

### Require signoff for merges

To require a signoff before PRs can be merged:

```bash
gh signoff install
```

---

Things you may want to cover:

* Ruby version

* System dependencies

* Configuration

* Database creation

* Database initialization

* How to run the test suite

* Services (job queues, cache servers, search engines, etc.)

* Deployment instructions

* ...
