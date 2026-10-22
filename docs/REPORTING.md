# Reporting audit and design decision

Audited on October 22, 2026. Audience assumptions come from the product brief: small business owners and staff, limited technical confidence, familiar with Excel, and occasional custom reporting needs. This is a code and workflow audit, not an observed-user usability study.

## Decision

Keep reports inside the existing Rails/Inertia/Svelte application. Use a searchable library of ready-made reports for everyday questions and a guided **Custom Excel export** for occasional bespoke work. Retain **Caxlsx** for native `.xlsx` workbooks and use **Chart.js** for the browser charts.

| Option | Fit for this application | Decision |
| --- | --- | --- |
| Native library + Caxlsx + Chart.js | Existing authentication, business vocabulary, saved results, and Excel workflow; no additional reporting service | Implemented |
| Blazer | Integrates with Rails and is useful for developer-authored SQL questions, but writing SQL is a poor default for the stated audience | Reconsider for internal analyst tooling if a recurring need emerges |
| Embedded Metabase | Strong visual query builder, but adds a BI application, database access configuration, embedding, and another permissions model | Reconsider if users need frequent joins, shared dashboards, or complex self-service analysis |

Primary references: [Caxlsx](https://github.com/caxlsx/caxlsx), [Chart.js integration](https://www.chartjs.org/docs/latest/getting-started/integration.html), [Blazer](https://github.com/ankane/blazer), [Metabase embedding](https://www.metabase.com/docs/latest/embedding/introduction). The choice above is a product judgment based on the stated audience, not a claim that one tool is universally superior.

## Findings and changes

- Excel detail cells were converted to strings. Money and dates looked useful but could not reliably be totaled, sorted, or pivoted. Exports now use declared column types, numeric money and percentages, real Excel dates, and text identifiers. Text is escaped against spreadsheet formula interpretation.
- Several templates discarded detail beyond 100, 500, or 2,000 rows. New report snapshots now retain every matching row; only chart highlights and the on-screen page are limited. Excel receives all stored rows and splits results at Excel's worksheet row limit.
- Blank parameter controls hid implicit date defaults. Invalid dates silently fell back, reversed ranges could produce empty reports, and select values were not validated. The form now shows month-to-date defaults, common date shortcuts, and field choices. The server validates ISO dates, range order, supported choices, and a ten-year maximum range before enqueueing. Resolved dates are persisted before the job runs.
- Pending screens promised eventual results without refreshing. Status now polls while pending or processing, stops after completion, and loads result data through the existing Inertia deferred group. Export actions appear only when results are complete.
- The old chart substitute displayed only the first series, treated all chart types as bars, could not display negative values correctly, and ignored nested discount charts. Chart.js now renders the full data, with an expandable accessible values table. Held orders are visible separately and exported separately.
- Report creation required a button in the application command bar. The setup screen now has its own submit action, clear validation feedback, and protection against repeated submissions while a request is active.
- Staff were shown report creation/deletion controls they could not use. New controls follow existing CanCan permissions: administrators generate/delete; staff read/download.
- Multi-year daily charts used month/day keys, merging different years. Keys now include the year. The discount chart no longer subtracts discounts from an already-discounted order total, and refunded orders remain part of their original discount analysis.
- Sales summary labeled amounts including tax as net sales. New summaries use receipts including tax, and list all refunds issued in the period in a separate table and worksheet so returns for older sales remain visible.
- A notification exception could mark an already-generated report failed. Completion is now persisted separately; retries do not regenerate completed results. Deleted queued reports are ignored.

## Bespoke exports

Administrators choose **Sales**, **Refunds**, **Inventory**, or **Customers**, select columns, optionally name the result, and generate it. Sales/refund datasets use the selected dates; inventory/customers are current snapshots. Each dataset has a fixed row meaning and a reviewed column allowlist. Selecting columns does not evaluate SQL, arbitrary associations, or arbitrary model attributes. Only selected columns are stored in the result.

A saved result's **Change settings / run again** link pre-fills its choices. It produces a new snapshot, preserving the old one. In Excel, the Data worksheet opens first and includes a formatted table, filter controls, and frozen header. Summary records the generation details, settings, and report summary. Use Excel's table filters, `SUM`, or **Insert → PivotTable** for further analysis.

This deliberately supports common bespoke extracts rather than a general database query builder. New business-specific reports can still be added as template subclasses. The column metadata is captured with new snapshots, so future template changes do not reinterpret their exports.

## Calculation boundaries

Report descriptions state their scope; similarly named reports are not interchangeable accounting ledgers:

- Sales summary recognizes sales on completion and refunds when issued. Receipts include tax. Tax on sales is before refund adjustments.
- Payment breakdown shows original sale payments before refunds. The refund model does not record refund tender.
- Item sales are after item discounts, before order-level discounts/refunds, excluding tax. The application does not allocate order-level discounts to items.
- Customer sales subtracts all refunds against orders completed in the selected period as of generation time. It is a customer cohort view, distinct from period cash movement.
- Tax on sales is before refund adjustments and is not a net remittance calculation.
- Inventory is valued at generation time, not reconstructed historically.

Historical snapshots are retained as generated. Older truncated reports need to be generated again to obtain full detail; exporting an old result cannot recover rows that were never stored. Processing and exports still build their datasets in memory. The intended small-business workload is supported; large warehouses or millions of rows would warrant streamed/background file exports rather than enlarging this interface.

## Extending reports

Add a `ReportTemplate` subclass with `key`, `title`, `description`, `parameters`, `generate`, `table_columns`, and `register!`. Declare `type` for numeric/date columns (`currency`, `integer`, `percentage`, `date`, `datetime`); identifiers default to text. Existing display-formatted money is accepted for legacy snapshots. Result shape remains `summary`, `chart`, and `table`, with optional `held_orders_table` and `additional_tables` (`name`, `columns`, `rows`). The job stores the resolved output columns with the result.

Any future custom dataset should maintain one explicit row grain, eager-load required associations, expose only approved business fields, and explain its date/refund treatment. It should not accept SQL fragments from the browser.
