# PeopleDesk first fixes

This update focuses on authentication/profile handling, employee registration, and employee UUID references.

## Files changed

- `js/app.js`
  - Stops silently replacing failed database reads with empty arrays.
  - Shows a workspace error with a retry action when Supabase reads fail.
  - Requires a real `profiles` row for a signed-in user instead of silently assigning an Employee role.
  - Gives clearer errors for missing/inactive profiles.
  - Displays the human-readable `employee_id` in the employee directory.
  - Validates employee registration and stores optional fields as SQL NULL.
  - Resolves human-readable employee codes to the employee table UUID before inserting leave and training records.
  - Resolves payroll employee IDs to UUIDs, converts the month input to the first day of that month, and omits `net_salary` because the database generates it.
  - Checks that attendance users are linked to an employee record.

## Important setup notes

1. The Supabase SQL schema creates tables and policies; it does not create an administrator login.
2. Create a user in Supabase Dashboard → Authentication → Users.
3. Create a matching row in `public.profiles` using that Auth user's UUID as `id`. Set `role` to one of: `administrator`, `hr`, `manager`, `payroll`, `employee`.
4. For employees who need attendance or self-service, set `profiles.employee_id` to the matching `employees.id` UUID. Do not use the readable `employees.employee_id` code in this foreign-key column.
5. Do not place a service-role key or database password in `js/config.js`. A publishable/anon key is expected in a browser app, but production access must be protected by correct Row Level Security policies.
6. Do not rerun the complete `database/schema.sql` against a database that already has these tables. Use reviewed, additive migrations for future schema changes.

## Not yet addressed

This is the first repair pass, not a declaration of production readiness. Leave balances/approval authorization, attendance timezone and lateness rules, training programme workflows, appraisal workflows, payroll approval/payment, and full RLS policy review still require separate work and end-to-end testing.


## Security hardening migration

A follow-up RLS hardening migration is provided in `database/migrations/20261118_rls_hardening.sql`. Review `docs/RLS-HARDENING.md` for its access model, prerequisites and role-based test checklist. The migration has not been run against the live Supabase project; take a backup and test it in a staging project before production use.
