# Phase 9 — Manual Staging Test Checklist

Use a staging Supabase project and synthetic employee data only. Record tester, date, account role, test result, evidence and defect ID.

## Authentication and profiles
- [ ] Valid login and invalid login.
- [ ] Password reset.
- [ ] Session refresh and logout.
- [ ] Inactive profile is denied.
- [ ] Auth user without linked employee profile handled safely.
- [ ] Invite account, confirm email flow and profile linkage.

## Authorization/RLS (run each scenario using separate accounts)
- [ ] Employee can view own permitted records only.
- [ ] Employee cannot view other employees' payroll, appraisal scores or personal data.
- [ ] Manager access limited to permitted direct/department scope.
- [ ] HR access matches approved HR responsibilities.
- [ ] Payroll role cannot change user roles or access unrelated confidential HR records.
- [ ] Administrator can administer system roles.
- [ ] Anonymous access is denied for private HR tables.
- [ ] Direct REST/API attempts obey RLS, not just UI restrictions.

## Employee management
- [ ] Create, edit and deactivate employee.
- [ ] Duplicate employee code rejected.
- [ ] Required fields and date validation.
- [ ] Profile sync after employee changes.
- [ ] Deactivated employee account cannot sign in/use app.

## Attendance and leave
- [ ] Clock-in, clock-out and duplicate-day behavior.
- [ ] Clock-out before clock-in rejected.
- [ ] Shift grace period/lateness calculation.
- [ ] Overnight shift edge case documented/tested.
- [ ] Holiday/weekend calculations.
- [ ] Leave application date validation and overlap rejection.
- [ ] Leave balance enforcement.
- [ ] Manager/HR approval and rejection.
- [ ] Balance deduction and notification behavior.

## Payroll
- [ ] Generate one payroll period from synthetic salary records.
- [ ] Validate salary components, taxable status, SSNIT and PAYE independently.
- [ ] Test boundaries of each tax band and statutory cap/floor.
- [ ] Verify employee/employer contributions.
- [ ] Prevent duplicate period generation.
- [ ] Draft -> Approved -> Paid transition permissions.
- [ ] Locked/paid records cannot be altered by unauthorized roles.
- [ ] Payroll exports and employee visibility.

## Training and performance
- [ ] Training request submitted, approved/rejected, enrolled and evaluated.
- [ ] Capacity and participant duplicate handling.
- [ ] Appraisal period and criteria setup.
- [ ] Weighted score calculation.
- [ ] Employee self-assessment and manager review.
- [ ] Finalization and acknowledgement.
- [ ] Confidential appraisal score access verified.

## Recruitment and succession
- [ ] Vacancy created and approved.
- [ ] Candidate registered and status transitions validated.
- [ ] Interview scheduling and outcomes.
- [ ] Candidate records restricted to authorized HR roles.
- [ ] Succession plan and readiness assessment.
- [ ] Development action assignment and completion.

## Reports and notifications
- [ ] Dashboard metrics reconcile to source rows.
- [ ] CSV export contents, encoding and date formats.
- [ ] Role restrictions on report exports.
- [ ] Leave, training, payroll, appraisal and recruitment notifications.
- [ ] Read/unread state and notification ownership.
- [ ] No duplicate or unintended notification recipients.

## UI and deployment
- [ ] No browser console errors on all routes.
- [ ] Loading, empty, retry and error states.
- [ ] Responsive layout at phone/tablet/desktop widths.
- [ ] Keyboard navigation and accessible labels.
- [ ] Supabase Auth redirect URLs and email templates.
- [ ] Edge Function secrets and deployment.
- [ ] Backup/restore test.
- [ ] Production domain and HTTPS.
- [ ] Final stakeholder acceptance.
