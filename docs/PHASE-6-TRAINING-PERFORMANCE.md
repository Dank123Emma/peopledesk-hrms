# PeopleDesk HRMS – Phase 6: Training and Performance

## Scope

This phase completes operational workflows for training management and performance appraisal using the existing Supabase schema.

### Training management
- Employees and HR can record training needs.
- HR/authorized departmental managers can approve or reject requests. Rejections require a reason in the UI.
- HR can create programmes with category, provider, trainer, venue, objectives, dates, budget, capacity and status.
- HR enrols employees. A database RPC enforces programme status, duplicate enrolment and capacity.
- HR records attendance, completion and certificate reference.
- Attended participants can submit post-training evaluation scores and feedback.
- HR can view evaluations.

### Performance appraisal
- HR configures review periods and active criteria/weights.
- HR and managers can create appraisals for permitted employees.
- Employees can submit self-assessment through a database RPC.
- Assigned managers/HR enter criterion scores, criterion comments, manager feedback, strengths and a development plan.
- The weighted score is calculated by the client helper for review and recalculated in the database at finalization.
- Finalization requires every active criterion to have a score; it locks the appraisal and scores.
- Employees can acknowledge finalized appraisals through a database RPC.

## Database deployment

1. Back up the Supabase database.
2. Apply prior migrations if not already applied: Phase 1 security hardening, Phase 3 profile sync, Phase 4 attendance/leave, Phase 5 payroll.
3. Execute `database/migrations/20261119_phase6_training_performance.sql` in Supabase SQL Editor.
4. Confirm no SQL errors and verify that the migration's new columns, policies and RPCs exist.
5. Sign in with separate HR, manager and employee test accounts.

The Phase 6 migration is additive to the current schema. It alters existing training and appraisal tables, replaces named legacy policies, and creates functions for participant enrolment, self-assessment, appraisal finalization and acknowledgement.

## Access rules

- Training needs: HR/admin, the employee, or an authorized manager scoped to the employee's department.
- Training programmes: authenticated users can read; HR/admin can create or change programmes.
- Training participants: employee can read their own participation; HR/admin manages enrolment and status.
- Training evaluations: HR/admin and the participant can read scoped records; participants can submit an evaluation only after attendance.
- Appraisal periods and criteria: authenticated users can read; HR/admin manages them.
- Appraisals: HR/admin, assigned manager and employee can read scoped records; HR/admin and assigned managers manage reviews. Employee self-assessment uses a security-definer RPC.
- Appraisal scores: visible only to HR/admin, assigned manager and the appraised employee; managers/HR can change scores only before finalization.
- Finalized appraisals cannot be changed through the workflow; acknowledgement is handled through a scoped RPC.

## Manual verification checklist

### Training
- [ ] Employee submits a training need for their own employee profile.
- [ ] Employee cannot submit a need for another employee.
- [ ] HR can approve a request.
- [ ] Manager cannot approve a request outside their department.
- [ ] HR creates a programme and its capacity is saved.
- [ ] HR enrols an employee.
- [ ] Duplicate enrolment is rejected.
- [ ] Enrolment beyond capacity is rejected.
- [ ] HR updates attendance and completion.
- [ ] Participant cannot evaluate before being marked Attended.
- [ ] Participant submits evaluation and HR can review it.

### Performance
- [ ] HR creates an appraisal period and criteria.
- [ ] Manager can create an appraisal only for permitted employees.
- [ ] Employee submits self-assessment for their own appraisal.
- [ ] Manager enters scores from 1–5 and criterion comments.
- [ ] Invalid scores and inactive criteria are rejected.
- [ ] Weighted score preview is calculated.
- [ ] Finalization rejects appraisals missing an active criterion score.
- [ ] Database recomputes the weighted score at finalization.
- [ ] Finalized appraisal and scores cannot be edited.
- [ ] Employee acknowledges their finalized appraisal.
- [ ] User cannot view another employee's appraisal or scores.

## Notes

- The local demo workspace supports UI workflow previews. Demo data is not persisted and is not evidence of live Supabase integration.
- This migration has been statically reviewed and packaged but has not been executed against the live database in this environment.
- The organization should approve training policy, capacity, appraisal criteria, weights and review periods before production use.
