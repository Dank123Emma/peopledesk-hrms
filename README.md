# PeopleDesk — Human Resource Management System

A static HTML/CSS/JavaScript HRMS frontend with Supabase PostgreSQL, Supabase Auth and Row Level Security integration.

## Included modules
- Dashboard and workforce snapshot
- Employee directory and registration
- Attendance clock-in / clock-out
- Leave applications and HR approval
- Training needs
- Performance appraisal criteria and recognition record
- Payroll records and GHS calculations
- Succession planning
- Recruitment application tracking
- CSV report exports

## Important implementation status
This repository is a functional starter application, not a production-certified HR/payroll platform. Demo mode is enabled until Supabase credentials are configured. Demo data is stored in browser memory and is reset on refresh. The SQL schema and RLS policies provide a starting point; review and test them with your organization's exact roles and policies before using real employee data.

The current UI provides working CRUD entry points for employee registration, leave, training needs, payroll records, succession plans and recruitment applications. Production workflows such as PDF payslips, weighted appraisal scoring, statutory payroll deductions, document uploads, full audit triggers, approval chains and comprehensive notification delivery require additional implementation and verification.

## Run locally
Because the application uses JavaScript ES modules, serve the folder using a local static server. For example:

```bash
python -m http.server 8000
```

Open `http://localhost:8000`.

## Configure Supabase
1. Create a Supabase project.
2. Open the SQL Editor and run `database/schema.sql`.
3. Run `database/migrations/20261118_rls_hardening.sql` to replace the starter RLS policies with the hardened role-scoped policies. Back up an existing database first.
4. Optionally run `database/seed-demo.sql` only in a separate test project.
5. In Supabase Authentication, enable email/password sign-in.
6. Create the first Auth user from the Supabase dashboard, then provision its `public.profiles` row from a trusted SQL Editor context. Assign the first administrator role only through this trusted provisioning path.
7. For subsequent users, add a matching `profiles` row with the Auth UUID and an authorized role. Employee users should also have an `employee_id` referencing `employees.id`.
8. Copy the project URL and publishable/anon key into `js/config.js`.
9. Set `DEMO_MODE` to `false` after supplying valid credentials.
10. Configure private Storage buckets and their policies before enabling confidential document uploads.

Example profile bootstrap (replace the UUID with the actual Auth user UUID):

```sql
insert into public.profiles(id, full_name, role)
values ('AUTH-USER-UUID-HERE', 'HR Administrator', 'administrator');
```

Do not expose the Supabase service-role key in frontend code. The publishable/anon key is designed for client use only when RLS is correctly configured.

## GitHub Pages deployment
1. Push this project to a GitHub repository.
2. In repository Settings → Pages, select Deploy from a branch.
3. Select `main` and `/ (root)`.
4. Save and wait for deployment.
5. Configure the Supabase Auth Site URL and redirect URLs to include your GitHub Pages URL, for example `https://YOUR-USERNAME.github.io/YOUR-REPOSITORY/`.

GitHub Pages hosts only static frontend files. Supabase provides the database and backend services. For trusted operations, use Supabase Edge Functions or secure PostgreSQL functions; never rely on browser-only validation for payroll, approvals or privileged changes.

## Security checklist before real use
- Test every RLS policy using separate administrator, HR, manager, payroll and employee accounts.
- Restrict employee data by actual employee identity and department.
- Review manager approval authority.
- Add server-side audit triggers and prevent users from editing audit records.
- Keep payroll and salary tables restricted.
- Configure private storage and signed URLs for confidential files.
- Configure backups, retention, password policy and MFA as appropriate.
- Obtain legal/payroll review of Ghana statutory calculations and retirement rules.
- Do not enter real employee personal or financial information into the demo environment.

## Technology
HTML5 · CSS3 · Vanilla JavaScript · Supabase JS · PostgreSQL · Chart.js


## Phase 2 – Frontend/Supabase integration corrections

See `docs/PHASE-2-INTEGRATION.md` for the changes aligning frontend data loading and display fields with the Supabase schema, including employee joins, attendance time formatting, payroll mapping, page-scoped loading and role-aware navigation. These changes have passed JavaScript syntax checks but still require live Supabase and role-based verification.


## Phase 3 – Employee and account administration

See `docs/PHASE-3-EMPLOYEE-ACCOUNTS.md` for employee record management, Supabase Auth invitations, Edge Function deployment and role restrictions. Deploy `supabase/functions/peopledesk-admin` and configure its server-side secrets before using User Accounts.


## Phase 4 – Attendance and Leave Management

See `docs/PHASE-4-ATTENDANCE-LEAVE.md` for the Phase 4 scope and deployment steps. Apply `database/migrations/20261118_phase4_attendance_leave.sql` only after the base schema and Phase 1 RLS migration. Configure organization-approved leave entitlements in `leave_types`, configure shifts, assign employees to shifts, and enter public holidays before relying on automated calculations.

## Phase 5 – Payroll Management

See `docs/PHASE-5-PAYROLL.md`. Apply `database/migrations/20261119_phase5_payroll.sql` after earlier migrations. Payroll uses effective-dated statutory configuration, employee components, protected generation/approval/paid RPCs and configurable tax bands. The 2026 PAYE and SSNIT values are seeded but must be verified before production. Run `node tests/payroll-calculator.test.mjs` to validate the demo calculator.

## Phase 6 – Training and Performance

Phase 6 adds operational training-needs approval, training programme scheduling, participant enrolment and status tracking, post-training evaluations, appraisal periods and weighted criteria, employee self-assessment, manager review, finalization and employee acknowledgement.

See `docs/PHASE-6-TRAINING-PERFORMANCE.md` and apply `database/migrations/20261119_phase6_training_performance.sql` after the previous project migrations.

## Phase 7 — Recruitment & Succession Planning

This phase adds vacancy approval, candidate applications, interview scheduling/evaluation, critical-position succession plans and successor development actions. See `docs/PHASE-7-RECRUITMENT-SUCCESSION.md` and run the additive migration `database/migrations/20261119_phase7_recruitment_succession.sql` after earlier migrations.

Vacancies must be submitted for approval and opened by an Administrator. Candidate/interview records are restricted to HR and Administrators by RLS. Managers have department-scoped read access to succession plans and development actions; HR/Administrators manage them.

## Phase 8 — Reports, Analytics & Notifications

Phase 8 adds a role-aware reports workspace, HR dashboard metrics, CSV export for operational datasets, an in-app notification bell, and database-triggered notifications for leave decisions, training status changes, payroll approval/payment, finalized appraisals, and new recruitment applications.

Apply `database/migrations/20261119_phase8_reports_notifications.sql` after backing up the database. See `docs/PHASE-8-REPORTS-NOTIFICATIONS.md` for setup, verification and limitations.

## Phase 9 — System QA

Phase 9 adds a static QA suite and manual staging checklist. See `docs/PHASE-9-QA-REPORT.md` and `docs/PHASE-9-TEST-CHECKLIST.md`. Run `node --test tests/*.test.mjs`. The suite verifies source syntax and static integration points; it is not a replacement for live Supabase, browser, RLS, or payroll acceptance testing.
