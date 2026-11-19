# Phase 8 — Reports, Analytics & Notifications

## Scope

Phase 8 adds a role-aware reporting workspace, additional workforce analytics on the dashboard, CSV exports for the operational modules, and an in-app notification panel.

## Dashboard metrics

HR and administrators see the metrics available in their RLS-filtered datasets:
- Active workforce and employee-record count
- Attendance records for the current date in `Africa/Accra`, with late counts
- Pending leave applications
- Completed training participants
- Open vacancies and candidate count
- Latest payroll period and net payroll total
- Appraisal record count
- Succession plan count and ready successors

Other roles retain a role-appropriate dashboard view. These numbers reflect records the signed-in user can read; they are not intended to bypass RLS.

## Reports

The Reports workspace exposes CSV exports for employee directory, attendance, leave, training needs, training programmes, performance appraisals, payroll, recruitment pipeline, vacancies and succession planning. The available reports are filtered by the application role and the underlying Supabase policies. Export fields are based on the current dataset; nested relationship fields are serialized to JSON strings.

## Notifications

A notification bell opens the user's in-app notification panel. Users can mark individual notifications as read. The existing `notifications` table and own-row RLS policies are used.

The migration creates database-triggered notifications for:
- Leave application decisions (Approved/Rejected)
- Training request status changes
- Payroll status changes to Approved or Paid
- Finalized performance appraisals
- New recruitment applications (sent to active HR and administrator accounts)

Trigger functions are `SECURITY DEFINER` with a fixed `search_path`; execute privileges are revoked from client roles. The functions create notifications through the database event, not arbitrary client inserts.

## Installation

1. Back up the Supabase database.
2. Execute `database/migrations/20261119_phase8_reports_notifications.sql` in the Supabase SQL Editor.
3. Refresh the application and test the bell using accounts with different roles.
4. Trigger test events: decide a leave request, change a training request status, approve/mark payroll paid, finalize an appraisal, and add a recruitment application.
5. Confirm the recipient sees only their own notifications and can mark them read.

## Verification

Run all project tests from this folder:

```bash
node --test tests/*.test.mjs
```

The tests validate application syntax, calculator regressions, Phase 8 UI/report references and migration structure. They do not replace execution against the live Supabase database or role-by-role integration tests.

## Limitations

- CSV exports are current-view exports, not scheduled report jobs.
- Dashboard figures are limited by RLS and the datasets loaded for the current role.
- Notifications are in-app only; email, SMS, push notifications and scheduled reminders are not included.
- There is no custom date-range report builder yet.
- Notification events occur when the relevant database status transition happens after the migration is installed.
