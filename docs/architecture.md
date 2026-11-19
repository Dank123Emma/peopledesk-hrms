# Architecture notes

## Deployment
The browser downloads static HTML, CSS and JavaScript from GitHub Pages. The Supabase JavaScript client communicates with Supabase Auth and PostgREST over HTTPS. PostgreSQL RLS is the security boundary for database access.

## Trust boundaries
The browser is untrusted. Client-side checks improve usability but do not authorize sensitive operations. Payroll approval, statutory deductions, leave-balance mutation, attendance corrections and privileged role changes must be enforced by PostgreSQL policies/functions or Supabase Edge Functions.

## Core relationships
- `employees` is the central workforce entity.
- `profiles` links an authenticated Supabase user to an employee and role.
- `attendance_records`, `leave_applications`, `training_needs`, `performance_appraisals`, `salary_structures` and `payroll_records` reference employees.
- `training_programmes` connects to employees through `training_participants`.
- `performance_appraisals` connect to criteria through `appraisal_scores`.
- `payroll_records` connect to line items through `payroll_items`.

## Operational caveats
The initial schema is a foundation and must be reviewed before production. In particular, implement an audited approval workflow, server-side attendance rules, leave-day calculations that respect working calendars, secure document storage, and tested payroll calculations.
