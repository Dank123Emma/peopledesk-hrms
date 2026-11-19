# PeopleDesk HRMS — Phase 7: Recruitment & Succession Planning

## Scope
Phase 7 expands the previous basic recruitment application and succession-plan forms into HR workflows. It is an additive migration and preserves existing records.

## Recruitment workflow
1. HR creates a vacancy in Draft.
2. HR submits the vacancy for approval (Pending Approval).
3. An Administrator approves and opens the vacancy. Opening is enforced by the `approve_job_vacancy` database function and approval guard trigger; HR cannot open a vacancy directly.
4. HR registers candidate applications against open vacancies.
5. Candidate status progression: Received → Under Review → Shortlisted → Interviewed → Selected. HR may reject a candidate before selection.
6. HR schedules interviews and records outcome, score and feedback.
7. The most recent interview score is reflected in the candidate application's evaluation score.
8. HR closes a vacancy when recruitment is complete.

## Succession workflow
- HR creates a plan for a critical role, links the incumbent and potential successor to employee records, and records department, risk level, readiness, training status and transition date.
- HR updates readiness assessments and development plans.
- HR creates successor-development actions with an owner and due date.
- Development actions may be marked Completed.
- Managers can read plans and actions for their own department; only HR/Administrators manage plans and development actions.

## Database migration
Run `database/migrations/20261119_phase7_recruitment_succession.sql` in Supabase SQL Editor after the prior HRMS migrations.

The migration creates:
- `job_vacancies`
- `recruitment_interviews`
- `succession_development_actions`

It adds workflow fields to `recruitment_applications` and `succession_plans`, indexes and RLS policies. It replaces broad legacy succession/recruitment policies with scoped policies. Candidate and interview data is HR/Admin-only. Vacancy approval is administrator-only through `approve_job_vacancy(uuid)`.

## Security notes
- The browser uses the Supabase anon/publishable key and user session. Never place the service-role key in frontend code.
- RLS is the authorization boundary; UI role checks are convenience controls.
- The migration assumes earlier schema and security migrations have already been applied.
- Managers only read succession records matching their profile department. Existing succession plans should have `department` populated to be visible to managers.
- Candidate PII should be retained only under the organization's approved recruitment retention policy.

## Test checklist
### Vacancies
- [ ] HR creates a Draft vacancy.
- [ ] HR submits it to Pending Approval.
- [ ] HR cannot approve/open it.
- [ ] Administrator approves and opens it.
- [ ] Direct HR update to Open is rejected by trigger.
- [ ] HR/Admin closes an Open vacancy.
- [ ] Closing dates cannot precede opening dates.

### Applications
- [ ] Candidate can be registered only against an Open vacancy.
- [ ] Application shows vacancy, contact details, date and stage.
- [ ] Valid stage progression is enforced.
- [ ] Rejection works before selection.
- [ ] Selected and Rejected are terminal stages in the UI.

### Interviews
- [ ] Interview is scheduled with date/time, type, location, panel and notes.
- [ ] Outcome and 0–100 score are validated and recorded.
- [ ] Interview score updates the application score.
- [ ] HR/Admin can read and manage interviews; other roles cannot read candidate/interview data.

### Succession
- [ ] HR creates a plan with different incumbent and successor employees.
- [ ] Readiness and risk can be assessed.
- [ ] Development actions are created with optional owner and due date.
- [ ] Development action can be marked completed.
- [ ] HR/Admin can manage plans/actions.
- [ ] Managers can read their department's plans/actions but cannot modify them.

## Verification performed in this package
- JavaScript syntax checks.
- Existing payroll calculator tests.
- Existing performance calculator tests.
- Recruitment/vacancy transition tests.
- ZIP integrity checks.

Live Supabase migration execution and role-based testing must be completed in the connected project before production use.
