# Test plan

## Authentication
- Valid and invalid login.
- Password reset.
- Session refresh and logout.
- Disabled account rejection.

## Authorization
- Employee reads only own records.
- Manager reads only permitted department records.
- HR can manage employee and leave records.
- Payroll role can manage payroll but not user roles.
- Administrator manages system access.
- Anonymous requests cannot read private tables.

## HR operations
- Duplicate employee ID is rejected.
- Invalid employment dates are rejected.
- Duplicate daily attendance is rejected by unique constraint.
- Clock-out cannot precede clock-in.
- Leave end date cannot precede start date.
- Duplicate employee/payroll period is rejected.
- Payroll deductions cannot exceed earnings.
- Unauthorized approval/update attempts are rejected.

## UI
- Mobile navigation.
- Keyboard-accessible forms.
- Empty and error states.
- Search and CSV export.
- Verify no browser console errors.

## Phase 7 — Recruitment & succession
See `PHASE-7-RECRUITMENT-SUCCESSION.md` for the complete role-based test checklist. Run `node tests/phase7-workflow.test.mjs` for candidate-stage and vacancy-transition unit tests.
