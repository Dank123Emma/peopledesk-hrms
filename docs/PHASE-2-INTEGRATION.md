# PeopleDesk HRMS – Phase 2 Integration Corrections

## Scope

This phase aligns the existing browser application with the columns and relationships defined in `database/schema.sql`. It does not change the database schema and does not claim that the live Supabase project has been tested.

## Changes made

### 1. Related employee data

Attendance, leave, training-needs and payroll queries now request the related employee record through the existing `employee_id` foreign key. The frontend maps the related employee's `full_name`, `employee_id`, department and position into display fields used by the current screens.

### 2. Database-to-interface field mapping

- Employee status is mapped from `employment_status`.
- Employee salary display is mapped from `basic_salary`.
- Payroll `payroll_period`, `basic_salary`, `total_earnings`, `total_deductions` and generated `net_salary` are mapped to the existing payroll display fields.
- Payroll allowances are displayed as `total_earnings - basic_salary`.
- Payroll period is displayed as `YYYY-MM`.

### 3. Attendance display

- Clock-in and clock-out timestamps are displayed in `Africa/Accra` time.
- Worked hours are calculated from the stored clock-in and clock-out timestamps when both exist.
- Incomplete attendance records display zero calculated hours until clock-out is recorded.
- The attendance work date used for clock-in/out is derived in `Africa/Accra`, rather than UTC.

### 4. Page-scoped data loading

The application now loads only the datasets required by the current page. Role-specific page datasets are used for the dashboard and reports so that a user is less likely to fail a workspace load because of an unrelated table they are not authorized to read. Database RLS remains the security boundary; hiding navigation and buttons is only a user-interface convenience.

### 5. Role-aware navigation and actions

Navigation and create/approval controls are shown according to the profile role. The database RLS policies remain authoritative and must be tested independently. The UI checks are not a substitute for server-side authorization.

## Validation performed

- JavaScript syntax checks were run against the project's JavaScript modules.
- The integration code was compared with the table and column definitions in `database/schema.sql`.
- No live Supabase query, authentication session, or role-based database test was performed in this environment.

## Required verification in Supabase

After deploying the project, test with at least one account for each role:

1. Administrator
2. HR
3. Manager
4. Payroll
5. Employee

For each role, verify that allowed pages load, disallowed pages are hidden, and direct requests against restricted tables are denied by RLS. Confirm that joined employee names appear for attendance, leave, training and payroll records. Verify clock-in and clock-out around midnight in the `Africa/Accra` timezone.

## Known limitations not addressed by this phase

- Attendance lateness rules, shift assignment and server-authoritative time capture.
- Leave balance calculation and automated balance deduction.
- Full payroll computation, statutory deductions, approval and payment processing.
- Full performance appraisal workflow.
- Recruitment and succession workflow expansion.
- Audit-log integrity and independent security review.

These remain separate development tasks and should not be treated as completed by this integration phase.
