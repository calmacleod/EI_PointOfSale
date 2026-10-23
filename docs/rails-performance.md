# Rails performance audit — 23 October 2026

The project now targets **Ruby 4.0.8**, as requested, in the version file, mise configuration, Gemfile/lockfile, Dockerfile, and project documentation. The original audit below used Ruby 4.0.9; its historical measurements have not been relabeled. Ruby 4.0.9 was the latest stable release on the audit date, but its official Docker image had not yet been published. See the [official release](https://www.ruby-lang.org/en/news/2026/10/23/ruby-4-0-9-released/).

**Keep YJIT as the production choice.** ZJIT passed the application tests and compiled the benchmark workload, but was slower than YJIT on the important Ruby-heavy requests. The larger opportunities are customer-search SQL, full-catalog serialization, and deployment warm-up.

All four fixes below are now implemented locally. Production remains on commit `2862d64` / Ruby 4.0.1; these changes have not been deployed.

## Implemented fixes

- Customer lookup uses a stored generated search vector for both matching and ranking. The original tokenization, normalized phone digits, trigram matching, and name/ID tie-breakers are retained. Its partial GIN index replaces the old expression index.
- `Offline::CatalogSerializer` reads typed scalar columns and joined association values without instantiating catalog models. Decimal strings, nulls, local-time ISO timestamps, and discarded associations retain the existing payload contract.
- New offline clients request pages of at most **500 total records plus deletion IDs**, ordered by `(updated_at, id)`. Signed, collection-specific cursors carry the original upper timestamp, lower timestamp, page size, and last position; they expire after one hour. The server includes changes exactly at the previous watermark and preserves microseconds in sync metadata. Updates after the upper boundary are picked up by the next delta. This is timestamp-based synchronization, not a database snapshot across requests.
- IndexedDB stages pages on disk, then applies records, deletions, and the final watermark in one transaction. Failed HTTP pages, malformed responses, expired cursors, and failed IndexedDB writes leave the previous complete catalog usable. A retry starts from the previous watermark; full sync replaces the old catalog only at commit. Web Locks serialize the same collection across modern browser tabs. Staging temporarily needs additional local disk space, but does not retain the whole catalog in JavaScript memory.
- Clients with older cached JavaScript still receive a complete, unpaged response when they omit `page_size`. This compatibility path now uses scalar serialization, but remains unbounded until those clients refresh. IndexedDB moves to version 4; older tabs holding version-3 connections may need closing before the upgrade can finish.
- Concurrent `(updated_at, id)` indexes support cursor and delta scans for products, customers, services, and tax codes, including discarded rows.
- The Kamal hook now warms the configured public `APP_URL` after routing switches, requests login HTML explicitly, and fails on connection errors or any final status other than 200. `KAMAL_WARMUP_URL` can override the target for another environment. It warms liveness and login rendering, not authenticated checkout paths or the entire JIT workload.

**Migration note:** adding the stored customer column rewrites and locks the customer table while PostgreSQL populates it. Deploy outside checkout hours. The subsequent search and timestamp indexes are built concurrently. The migrations are reversible; the old release can still run during the upgrade, although its old expression search will be slower after that index is removed.

## Ruby 4.0.8 implementation validation

- Full Rails suite: **1,044 tests / 4,337 assertions**, passing with YJIT and again with ZJIT explicitly enabled.
- Browser suite: **79 tests / 570 assertions**, passing, including a catalog exceeding the page limit, full replacement, and offline lookup afterward. An initial run had seven login failures while a competing AMD64 build was running; subsequent runs passed with both four workers and the default twelve workers after the build finished.
- JavaScript: **11 tests**, passing, including page failures/retries, stable boundaries, repeated-cursor rejection, code swaps, atomic IndexedDB rollback, and a blocked version upgrade. Svelte: no errors or warnings.
- Steep: no type errors; signatures added for both services and regenerated for the customer column. RuboCop: **401 files**, no offenses.
- Both migrations rolled back and reapplied successfully on the isolated performance database. Regression coverage checks search matching/index use and selective kept/deleted timestamp scans.
- Production Docker builds passed using the published Ruby 4.0.8 image for native ARM64 and AMD64. The AMD64 Rails production-boot smoke test reported Ruby **4.0.8**, `x86_64-linux`, and YJIT enabled; no production credentials or database writes were used.
- The repaired hook completed ten read-only public requests (five `/up`, five HTML `/session/new`). Separate simulated 204 and connection-failure runs exited unsuccessfully instead of reporting success.

Further benchmark analysis was stopped at the user's request. Exploratory local runs are in `tmp/usability/performance-4.0.8/`; the historical results below remain the original audit.

## Original audit measurement method (Ruby 4.0.9)


- Code baseline: `2862d64`, with the Ruby upgrade and no endpoint behavior changes.
- Ruby 4.0.9, Rails 8.1.4, PostgreSQL 18. Native Linux ARM64 Docker container with jemalloc, two CPUs and 2 GiB memory limit. Production is AMD64, so these are comparative local results, not production latency forecasts.
- Dedicated database with 20,000 products, 20,000 customers, 2,000 services, tax/supplier/group associations, a signed-in admin, and a 12-line order. All synthetic data is rolled back. Experimental columns and indexes were verified absent afterward.
- Actual Rails routes, middleware, authorization, SQL, presenters and JSON rendering through `ActionDispatch::Integration::Session`. Eager loading enabled; reloading off; memory cache; APM disabled. This omits HTTP/TLS, Puma request queueing, production Solid Cache and monitoring overhead.
- Three fresh processes per compiler, with order rotated: interpreter/YJIT/ZJIT, ZJIT/interpreter/YJIT, YJIT/ZJIT/interpreter. No concurrent test/build workloads during measurements.
- Each ordinary read endpoint: 200 warm-ups and 300 measured requests per run. Broad customer search: 20/50. Full sync: 3/10. Barcode writes: 100/200 in separate processes, with a savepoint rollback per request to keep the cart constant. Write timings include savepoint overhead and exclude transaction-commit effects.
- Request query caches are cleared between requests. SQL and model-instantiation counts come from a separate diagnostic request, outside the timing sample. The JSON file includes per-run medians and sample sizes.
- Numbers below are the median of three run medians and, separately, the median of three run p95 values. Bulk p95 has only ten observations per run and should be treated cautiously. This is not a concurrency/capacity test or an old-Ruby-versus-new-Ruby comparison.

[Machine-readable results and query plans](performance/2026-10-23-ruby-api.json). Raw local runs are in `tmp/usability/performance/`.

## JIT results

Times are **median / p95 milliseconds**; lower is better.

| Request | Interpreter | YJIT | ZJIT |
| --- | ---: | ---: | ---: |
| Register popular items | 3.20 / 4.95 | 1.70 / 2.41 | 3.18 / 4.62 |
| Register exact-code search | 8.24 / 11.67 | 6.02 / 7.81 | 7.18 / 10.21 |
| Register selective search | 3.11 / 4.63 | 1.78 / 2.50 | 2.66 / 3.90 |
| Register broad search | 21.46 / 22.57 | 21.79 / 24.58 | 22.75 / 25.55 |
| Customer selective search | 2.55 / 3.76 | 1.98 / 2.71 | 2.79 / 4.39 |
| Customer broad search | 246.34 / 258.77 | 253.44 / 263.50 | 253.21 / 264.95 |
| Inventory barcode lookup | 2.75 / 3.20 | 1.96 / 2.67 | 2.61 / 3.82 |
| Global selective search | 3.40 / 4.55 | 2.47 / 3.61 | 3.53 / 5.31 |
| Product page, Inertia JSON | 9.48 / 11.80 | 4.87 / 6.81 | 6.42 / 8.17 |
| Register page, Inertia JSON | 11.48 / 14.34 | 7.59 / 9.72 | 8.80 / 11.75 |
| Empty product delta sync | 6.21 / 7.51 | 5.88 / 7.28 | 5.99 / 6.92 |
| Empty customer delta sync | 3.99 / 5.72 | 3.47 / 4.88 | 5.41 / 6.72 |
| Full product sync | 808.96 / 855.87 | 435.76 / 468.29 | 648.04 / 704.41 |
| Full customer sync | 427.69 / 454.87 | 239.22 / 257.36 | 336.21 / 386.97 |
| Full service sync | 46.81 / 61.41 | 24.53 / 35.81 | 36.46 / 48.84 |
| Scan into a 12-line cart | 21.06 / 25.03 | 12.16 / 15.77 | 15.52 / 21.26 |

YJIT reduced full-product-sync time by 46% versus the interpreter. ZJIT reduced it by 20%, but took 49% longer than YJIT. ZJIT also took 28% longer than YJIT for barcode scanning. The very small lookup differences are less useful than the larger CPU-heavy results because SQL and local scheduling account for much of their time.

ZJIT compiled approximately 5,000 instruction sequences per full run, with zero reported compilation failures. Both JITs spent roughly a second compiling over the complete benchmark process. The result is not an accidentally disabled-JIT comparison: the script asserts the active compiler after Rails boots and records runtime statistics.

Bulk responses dominate memory behavior. Maximum sampled RSS across runs ranged from 475–595 MiB for the interpreter, 507–539 MiB for YJIT, and 546–605 MiB for ZJIT. These snapshots include heap growth from fixture setup and previous endpoints; they are not precise peak-memory measurements or a clean isolation of JIT overhead. They do not establish a ZJIT memory advantage.

Ruby's [4.0 release notes](https://www.ruby-lang.org/en/news/2025/12/25/ruby-4-0-0-released/) describe ZJIT as experimental and advise holding off on production deployment. The measurements here give no reason to change that decision for this app.

## Original findings and prototype measurements

The suggestions in this section motivated the implemented changes above. Their numbers describe the original isolated experiments, not the final Ruby 4.0.8 implementation.

### 1. Materialize the customer search vector — highest measured query improvement

`Registers::Lookup::CUSTOMER_VECTOR` concatenates and tokenizes customer fields inside the ranking expression. The expression GIN index finds candidates, but broad queries still rebuild the vector to rank every matching customer.

On a deliberately broad query matching nearly all 20,000 customers, an isolated stored-vector prototype reduced query median from **232.55 ms to 27.27 ms (88%)**, preserving the same ordered IDs. Selective customer searches are already approximately 2 ms; this finding concerns common prefixes and large result sets, not every search.

Suggested change: add a stored generated `customers.search_vector`, index it with a partial GIN index for kept customers, and use that column for both matching and ranking. Preserve the existing tokenization, phone normalization, typo matching, ranking and tie-breakers. Add regression coverage for those behaviors and plan the table-rewrite/index migration separately. The experiment's DDL exists only inside a rolled-back transaction.

### 2. Reduce full-catalog serialization work, then bound full-sync size

The product endpoint instantiates about **20,005 Active Record objects**, allocates **1.30 million Ruby objects**, and builds roughly **10.3 MB of uncompressed JSON** in a single request. Customer sync similarly produces roughly 7.6 MB. Normal selective lookup requests stay small and use bounded query counts; this is a full-sync scaling issue.

An isolated product-sync prototype uses `left_joins`/`pluck` and explicit field conversion. In a direct before/after run with YJIT it reduced request median from **396.42 ms to 246.14 ms (38%)**, reduced SQL queries from six to three, and reduced instantiated models from 20,005 to two. The decoded full product payload was identical for the synthetic dataset.

Total Ruby allocations stayed near **1.30 million** and RSS did not improve in that experiment: JSON construction, repeated joined values, and the complete response still cost memory. Do not describe `pluck` alone as a memory fix.

Suggested changes:

1. Introduce a dedicated scalar serializer and validate decimal strings, nullable fields, time zones, discarded associations, common-user authorization, and delta/deletion behavior. The benchmark prototype implements only the full-sync case and is not a ready replacement controller.
2. Add bounded cursor pages for initial/full sync and update the IndexedDB client to consume every page before advancing the synchronization watermark. Preserve a stable sync boundary and deletion handling. This requires a coordinated client/server change; arbitrary `limit` calls would silently lose catalog data.

### 3. Repair the deployment warm-up hook

`.kamal/hooks/post-app-boot` defaults to `localhost:3000` and invokes local Docker inspection. Kamal 2.12 executes this hook with `run_locally`, while the application lives on the remote VPS. `KAMAL_CONTAINER_NAME` is provided to app containers, not this hook. The previous deployment recorded the hook finishing in 0.093 seconds; `curl ... || true` hides connection failures.

The login request also lacks `Accept: text/html`; production returned **204** to the current generic curl request, while the explicit HTML request returned **200** and rendered the page. Five such requests do not reliably warm the actual UI or its JIT workload. The hook's comment about running before proxy routing is also incorrect for the observed deployment order.

Suggested change: resolve the deployed web container on the remote host and warm it via SSH/container execution with the correct Host and HTML Accept headers, or use an explicit public-URL warm-up after deployment. Check response codes and report failures. Keep this separate from the liveness check: Rails `/up` does not prove that application queries or all UI paths are warm.

### 4. Index delta-sync timestamps — inexpensive scaling improvement

Products and customers have no `updated_at` index. An empty delta response can still scan the whole catalog. In query-only experiments:

| Empty delta query | Before | With `updated_at` index |
| --- | ---: | ---: |
| Products | 2.35 ms | 0.73 ms |
| Customers | 2.05 ms | 0.68 ms |

The absolute saving is modest at this size. Add indexes for the larger catalogs, verify both kept-record and deleted-ID plans, and measure with production-sized data. Do not present the query-only savings as equivalent endpoint savings.

## Production observations and limits

Read-only inspection showed four server CPUs, approximately 7.6 GiB RAM, and about 4.8 GiB available at that moment. Docker reported web memory usage of about 286 MiB, the worker about 424 MiB, and PostgreSQL about 186 MiB. This is a single snapshot, not a capacity forecast.

Existing logs contained very few authenticated API samples: only one sync request per collection for each inspected deployment. The current release's first observed product sync was 504 ms and tax sync 506 ms, but that sample is too small to establish steady-state p95 or attribute the delay to a specific cause. Most of the old release's approximately 2,900 requests were unauthenticated dashboard redirects/login requests. No 5xx responses appeared in the parsed completed-request sample. No production load test or production data mutation was performed.

Puma currently uses three threads and defaults to one worker. A later capacity test should compare one and two workers on native AMD64 with realistic concurrent checkout, lookup and sync traffic. CPU-bound serialization can contend for the Ruby VM lock; adding threads alone does not establish a throughput improvement. This audit does not claim a measured worker-count recommendation.

## Original Ruby 4.0.9 validation and Docker availability

- Ruby 4.0.9: full Rails suite **1,034 tests / 4,186 assertions**, passing under YJIT and again under ZJIT.
- Browser suite: **78 tests / 563 assertions**, passing.
- Steep: no type errors. RuboCop: **397 files**, no offenses.
- Native ARM64 production Docker image and assets built successfully. Rails production boot with ZJIT was verified using local storage and no production credentials.
- At audit time, Docker Hub had **not yet published `ruby:4.0.9-slim`**. Local validation built the exact official upstream recipe from commit `566c0b5ecc3c1c5ce82ab5a94962cb02ceaba14b`, whose Dockerfile SHA-256 was `b70a9f5b16a227b5709112a4e33b6aeea096b6dbb439f064a217a4303e9422a8`. The Ruby source archive checksum matches the official release.
- A fresh CI/Kamal builder using the normal Dockerfile will need that official image to become available, or an explicitly prepared source-built base. Native AMD64 image validation/deployment remains outstanding. No production runtime settings were changed.

## Reproducing the audit

Use a dedicated migrated test database, separately from the test suite. The script is test-only and rolls back its generated data. Run one compiler at a time. Example for YJIT:

```sh
source ~/.zshrc && eval "$(mise activate zsh)"
env -u RUBY_YJIT_ENABLE -u RUBY_ZJIT_ENABLE \
  RUBYOPT=--yjit EXPECTED_JIT=yjit RAILS_ENV=test \
  DATABASE_URL=postgresql://postgres:postgres@127.0.0.1:55432/pos_api_audit \
  PGGSSENCMODE=disable NEW_RELIC_AGENT_ENABLED=false \
  BENCH_OUTPUT=tmp/api-yjit.json \
  bin/rails runner script/benchmark_api.rb
```

Use `RUBYOPT=--zjit EXPECTED_JIT=zjit` for ZJIT; use `RUBYOPT='--disable-yjit --disable-zjit' EXPECTED_JIT=interpreter` for the interpreter. Environment flags survive Bundler's auto-switch/re-exec; direct `ruby --zjit bin/rails ...` lost its flag in the Docker check. The script aborts if the expected compiler is not actually active.

The prebuilt mise macOS Ruby 4.0.9 binary did not contain ZJIT. The tested local build used `MISE_RUBY_COMPILE=true RUBY_CONFIGURE_OPTS='--enable-yjit --enable-zjit --disable-install-doc' mise install --force ruby@4.0.9`. Rust 1.85 or later is required to build ZJIT; see [Ruby's build instructions](https://docs.ruby-lang.org/en/4.0/jit/zjit_md.html).

Additional controls:

- `BENCH_CASES=register_search,product_page` selects endpoints.
- `BENCH_WRITES=1 BENCH_CASES=scan_12_lines` exercises the write case with a savepoint rollback per request.
- `products_full`, `customers_full`, and `services_full` measure the compatibility responses. `products_page` and `customers_page` measure a 500-row page. `products_paged` and `customers_paged` consume every page and assert the final count; their total time includes client-side JSON decoding, but excludes network latency and IndexedDB work. Do not compare a single page with a complete catalog as if they performed equal work.
- The temporary DDL/controller prototypes were removed after implementation. Their original results and plans remain in the historical JSON artifact.
- `BENCH_PRODUCTS`, `BENCH_CUSTOMERS`, `BENCH_SERVICES`, `BENCH_WARMUP`, `BENCH_SAMPLES`, `BENCH_SLOW_WARMUP`, `BENCH_SLOW_SAMPLES`, `BENCH_BULK_WARMUP`, and `BENCH_BULK_SAMPLES` control scale and repetition.
- To match the reported Linux runs, run the script inside the built app image with `--cpus=2 --memory=2g`, `RAILS_ENV=test`, `SECRET_KEY_BASE_DUMMY=1`, the flags above, and a reachable isolated PostgreSQL URL. Mount the scripts read-only and the result directory writable. Preserve jemalloc from the image. Repeat each mode three times in rotated order.

Keep the raw measurements and report the hardware, data distribution, cache, runtime, sample sizes, and whether time includes HTTP and commits. Do not generalize these local synthetic measurements into production p95 or capacity promises.
