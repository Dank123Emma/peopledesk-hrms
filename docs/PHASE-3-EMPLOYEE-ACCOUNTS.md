# PeopleDesk HRMS – Phase 3: Employee Management and Account Administration

## Implemented in this package

### Employee records
- Expanded employee registration to capture contact details, employment type/status, date of birth, address, basic salary and emergency contact details.
- Added employee record editing for HR and administrator roles.
- Retained employee-code based identification in the directory.
- Employee records are deactivated through the employment status field rather than hard-deleted.
- The Phase 3 database trigger synchronizes a linked profile name and department after employee updates and disables linked access when employment status becomes `Inactive` or `Terminated`. Reactivation of account access requires the employment status to be `Active`.

### User accounts
- Added a role-restricted User Accounts workspace for HR and administrators.
- Added invitation flow linking an employee record to a Supabase Auth user and `profiles` row.
- HR may invite employee-role accounts and activate/deactivate employee accounts.
- Only administrators may assign privileged roles or change any account role.
- Self-deactivation is blocked by the Edge Function.
- Account provisioning uses a Supabase Edge Function and the service-role key only in server-side function secrets.
- Account actions attempt to write audit events to `audit_logs`.

## Deployment requirements

1. Apply `database/schema.sql` if the base schema has not already been created.
2. Apply `database/migrations/20261118_rls_hardening.sql` if Phase 1 was not already applied.
3. Apply `database/migrations/20261118_phase3_employee_profile_sync.sql`. Do not run the base schema over an existing populated database.
4. Deploy the Edge Function: `supabase functions deploy peopledesk-admin`.
5. Configure Edge Function secrets: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, and optionally `INVITE_REDIRECT_URL` (the deployed app's URL). The service-role key must never be placed in frontend files.
6. Confirm Supabase Auth email/SMTP settings and allowed redirect URLs so invitation emails can be delivered.
7. Ensure the first administrator profile is provisioned through a trusted SQL Editor/database-owner process. Do not create the first administrator from the public browser client.
8. Ensure employee email addresses are accurate. If an employee email is populated, the invitation email must match it.

## Account workflow

1. HR registers an employee and records a unique Employee ID and email address.
2. HR opens User Accounts and sends an invitation, selecting the employee and `employee` role.
3. The Edge Function validates the caller's active profile and role, invites the Auth user, and creates the linked profile.
4. The employee accepts the invitation and completes Supabase Auth onboarding.
5. An administrator may assign a privileged role if required.
6. HR or an administrator may deactivate/reactivate employee access. This toggles `profiles.is_active`; it does not delete the Auth user or employment record.

## Validation performed locally

- JavaScript module syntax checks.
- Edge Function TypeScript/structure review.
- ZIP archive integrity.
- Source-level review of the employee/profile relationships and existing RLS migration.

## Not verified in this environment

- Live Supabase Auth invitation delivery.
- Edge Function deployment or secret configuration.
- Live database insert/update behavior and RLS behavior for each role.
- SMTP delivery and invite redirect flow.

These require deployment to the user's Supabase project and tests with real role-specific accounts.
