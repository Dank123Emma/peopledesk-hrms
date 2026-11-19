# PeopleDesk HRMS – Supabase RLS hardening

## Purpose

`database/migrations/20261118_rls_hardening.sql` replaces the initial broad/incomplete Row Level Security policies with role- and employee-scoped policies. It is an additive policy/function migration: it does not drop application tables or delete business records.

## Before applying

1. Take a Supabase database backup (or create a restore point where available).
2. Confirm that `database/schema.sql` has already been applied and all 27 expected tables exist.
3. Apply this migration in Supabase Dashboard → SQL Editor, using a trusted project administrator account.
4. Review the SQL Editor output and confirm the transaction committed.
5. Do not put a Supabase `service_role` key in browser code, `.env` files committed to source control, or public repositories.

Do not rerun `schema.sql` on an existing populated database. Apply this migration only after the original schema.

## Access model introduced

| Area | Access rule |
|---|---|
| Profiles | Users read their own profile; HR/admin manage profiles; only administrators may assign/change privileged roles |
| Employees | Employees read themselves; managers read their department; HR/admin can read for HR duties; HR/admin manage employee records |
| Attendance | Employees create/read their own attendance; managers read department records; HR/admin correct records |
| Leave | Employees submit/read their own applications; managers see/decide within their department; HR/admin manage organization-wide |
| Leave balances | Employee and authorized HR/admin read; HR/admin manage balances |
| Training | Employees see their own needs/participation/evaluations; managers see department-scoped employee training needs; HR/admin manage programmes and records |
| Appraisals | Employee, assigned manager and HR/admin can access the relevant appraisal; appraisal scores inherit parent appraisal scope |
| Payroll | Employees see their own payroll and salary records; HR/admin/payroll have the operational access specified in the migration |
| Recruitment | HR/admin only |
| Succession | HR/admin and managers can read; HR/admin manage |
| Audit logs | Administrator read only from authenticated clients; no direct authenticated insert/update/delete policy |
| System settings | HR/admin only |

## Important implementation notes

- The manager scope currently uses the text `profiles.department` matched against `employees.department`. Ensure those values are consistent. A future improvement should use a manager-to-department or manager-to-team relationship with stable IDs.
- HR may create employee profiles but cannot assign a privileged role. Administrator provisioning can assign `administrator`, `hr`, `manager`, `payroll`, or `employee` roles.
- Provision the first administrator from a trusted SQL Editor/service-role context after creating the Supabase Auth user. The profile-role guard permits provisioning when `auth.uid()` is null; never expose privileged database credentials to the browser.
- Payroll officers do not receive broad access to the employee master table, which contains sensitive personal and emergency-contact fields. If payroll needs names or employee codes, provide a dedicated column-limited view or RPC rather than granting access to the full employee table.
- Employees can see their own payroll and salary-structure rows. Validate that the UI does not expose other employees' rows through cached client state or custom endpoints.
- RLS does not replace column-level authorization or business workflow validation. For example, a manager's leave update policy is row-scoped but does not by itself restrict which columns the manager may change. Before production, move approval into a narrowly scoped database function/RPC or add a trigger that prevents changes to applicant-controlled fields after submission.
- Audit logs should be written by trusted database triggers or server-side functions. The migration intentionally removes direct authenticated-client inserts.
- `service_role` and database owners bypass RLS by design. Keep those credentials server-side.

## Role-based test checklist

Use separate real Supabase Auth accounts for each role. Do not test only as the project owner or with a service-role key, because those contexts bypass RLS.

### Employee

- [ ] Can read own profile, employee record, attendance, leave applications, leave balance, training and appraisal where applicable.
- [ ] Cannot read another employee's personal, leave, attendance, appraisal or payroll records.
- [ ] Can submit own leave and training-need records only.
- [ ] Can create own attendance only; cannot update/correct attendance.
- [ ] Cannot read recruitment, succession, system settings or audit logs.
- [ ] Cannot change own role or profile permissions.

### Manager

- [ ] Can read employees and employee-related records only where `employees.department = profiles.department`.
- [ ] Cannot access records belonging to another department.
- [ ] Can decide leave applications only within the manager's department.
- [ ] Can access appraisals assigned to them / within their department as scoped.
- [ ] Cannot manage employee master records, profiles, payroll or system settings.

### HR

- [ ] Can manage employee/profile records and HR operational tables.
- [ ] Cannot assign or change a profile's privileged role.
- [ ] Can read payroll records for HR duties, but cannot create/update payroll records or salary structures under the current policy.
- [ ] Cannot read administrator-only audit logs.

### Payroll

- [ ] Can read employee identity data needed for payroll.
- [ ] Can manage payroll periods, payroll records, payroll items and salary structures.
- [ ] Cannot read leave, attendance, appraisal or recruitment data unless separately authorized.
- [ ] Can read only their own profile.

### Administrator

- [ ] Can administer all application data and assign roles.
- [ ] Can read audit logs.
- [ ] Confirm that all actions are attributable to the correct Auth user.

## Validation status

This migration has been statically reviewed against the supplied schema. It has not been executed against the user's live Supabase project, and role-based integration tests have not yet been run. Do not treat the database as production-ready until those tests pass.
