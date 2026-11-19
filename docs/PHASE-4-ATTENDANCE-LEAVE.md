# PeopleDesk HRMS – Phase 4: Attendance and Leave Management

## Scope delivered

### Attendance
- Employee clock-in and clock-out are performed through Supabase RPC functions using server-generated timestamps.
- The work date is derived in the `Africa/Accra` timezone.
- Duplicate clock-ins and clock-outs without an open attendance record are rejected.
- Shift assignments are effective-dated per employee.
- Lateness is calculated from the assigned active shift start time plus its grace period. If no active shift is assigned, the record defaults to `Present`; HR should assign shifts before relying on lateness reporting.
- HR and administrators can configure shifts, public holidays and employee shift assignments from the Attendance workspace.
- Completed hours are calculated from the stored timestamps in the frontend display.

### Leave management
- Employees submit requests against leave types configured in `leave_types`.
- Working days are calculated on the database, excluding Saturdays, Sundays and dates in `holidays`.
- The application rejects past start dates, invalid ranges, zero-working-day ranges, overlapping pending/approved requests and requests exceeding the available balance.
- The employee's balance is initialized from the configured leave type entitlement if no balance exists yet.
- Only HR, administrators or the employee's own department manager can decide a pending request.
- Approval updates `leave_balances.used_days` and the application status in one transaction.
- Rejections require a reason. Decisions and attendance events are written to `audit_logs`.

## Files added or updated

- `database/migrations/20261118_phase4_attendance_leave.sql`
- `js/app.js`
- `js/data.js`
- `docs/PHASE-4-ATTENDANCE-LEAVE.md`
- `README.md`

## Configure leave types

The migration intentionally does not invent entitlement values. After applying it, HR or the database administrator should configure the organization's approved policies. For example, after confirming the actual policy, insert or update records in `public.leave_types` with the correct `name`, `annual_entitlement` and `requires_document` values. The application currently selects configured leave types by name. Do not copy sample statutory values without checking the employer's policy and applicable law.

## Deployment

1. Back up the Supabase database.
2. Confirm the base schema and Phase 1 RLS hardening migration are already applied.
3. Apply the Phase 3 employee/profile synchronization migration if using the Phase 3 package.
4. Apply `database/migrations/20261118_phase4_attendance_leave.sql` in the Supabase SQL Editor.
5. Configure leave types in `leave_types`, including the organization's approved `annual_entitlement` values and whether supporting documentation is required.
6. Configure shifts in the Attendance workspace, then assign each employee a shift and effective date.
7. Add public holidays to the Attendance workspace. Weekends are excluded automatically; public holidays are excluded only when entered in `holidays`.
8. Test clock-in/out and leave workflows with separate employee, manager and HR accounts before using live records.

## Important policy/configuration notes

- The project does not assume statutory or organization-specific leave entitlements. HR must configure the correct entitlements in `leave_types` before use.
- The existing schema has no document attachment column or Storage workflow. Leave types marked `requires_document = true` are blocked by the RPC until a secure document-upload process is implemented. HR can handle those requests manually in the meantime.
- Shift assignment overlaps are not automatically prevented by a database exclusion constraint. HR should ensure that an employee has only one effective shift assignment on any given work date. Overnight shifts are not supported by this first attendance workflow; use same-day start/end times.
- Employees without an active shift assignment are not automatically classified as late.
- Attendance correction remains an HR/admin database operation. A dedicated correction workflow with mandatory reason and audit trail is a future enhancement.
- Demo mode stores changes only in browser memory and is not a persistent database.

## Local verification performed

- JavaScript syntax checks.
- Migration structure and key policy/function review.
- ZIP integrity check.

## Not verified here

- Execution against the user's live Supabase database.
- Actual RLS behavior across deployed user roles.
- Production SMTP, real attendance events, shift configuration and leave-balance accuracy.
- Organization-specific entitlement values and legal policy compliance.

These checks require deployment and testing in the actual Supabase project.
