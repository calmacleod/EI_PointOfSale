# Production Launch Runbook

Use this checklist before giving the POS to an associate for the controlled pilot.

## Preflight

- CI is green: Rails tests, system tests, RuboCop, Herb, Tailwind lint, Bundler audit, Importmap audit, and Brakeman.
- Production secrets are present: `RAILS_MASTER_KEY`, database credentials, Garage credentials, Google Drive backup credentials, and SMTP credentials.
- Password reset email works from production and uses `APP_URL`.
- Google Drive backups are connected from Admin > Backups.
- Web push is optional for the pilot. Configure `VAPID_PUBLIC_KEY`, `VAPID_PRIVATE_KEY`, and `VAPID_CONTACT` only if browser push notifications will be tested.

## Backup And Restore Rehearsal

1. From production console, run `DatabaseBackupJob.perform_now`.
2. From production console, run `GarageBackupJob.perform_now`.
3. Download both files from Admin > Backups.
4. Restore the database dump into a throwaway database with `pg_restore`.
5. Extract the Garage archive and confirm product/store images are present.
6. Record the filenames, restore target, restore command, and result.

## Associate Dry Run

Run the pilot flow end to end before launch:

- Create an active Common user and confirm sign-in.
- Mark the user inactive and confirm sign-in is rejected.
- Open the cash drawer.
- Complete cash, debit, and credit sales.
- View and print receipts.
- Sell and redeem a gift certificate.
- Process a partial refund, then a full refund.
- Close the cash drawer and reconcile debit/credit terminal totals.
- Generate a sales report.
- Confirm backup success notification or logs.

## Downtime Fallback

Offline sales are not supported for this pilot. `/offline` is lookup-only.

If the app is unavailable, write the sale on paper with item codes, quantities, customer, payment method, amount tendered, and terminal reference. Enter the order in the POS after service returns, then reconcile against the terminal/cash drawer notes.
