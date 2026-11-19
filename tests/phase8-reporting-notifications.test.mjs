import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const app = await readFile(new URL('../js/app.js', import.meta.url), 'utf8');
const html = await readFile(new URL('../index.html', import.meta.url), 'utf8');
const migration = await readFile(new URL('../database/migrations/20261119_phase8_reports_notifications.sql', import.meta.url), 'utf8');

test('Phase 8 dashboard includes operational analytics', () => {
  for (const metric of ['Active workforce','Attendance today','Pending leave','Training completion','Open vacancies','Latest payroll','Appraisals','Succession plans']) assert.ok(app.includes(metric), `missing metric: ${metric}`);
});

test('Phase 8 reporting exposes role-aware report exports', () => {
  for (const report of ['trainingProgrammes','appraisals','payroll','recruitment','vacancies','succession']) assert.ok(app.includes(report), `missing report dataset: ${report}`);
  assert.match(app, /data-action="export"/);
  assert.match(app, /role===\"administrator\"\|\|role===\"hr\"/);
});

test('Phase 8 notification UI supports unread and read actions', () => {
  assert.match(html, /data-action="open-notifications"/);
  assert.match(app, /data-action="mark-notification"/);
  assert.match(app, /read_at/);
});

test('Phase 8 migration creates event-driven notifications', () => {
  for (const trigger of ['trg_notify_leave_decision','trg_notify_training_request','trg_notify_payroll_status','trg_notify_appraisal_finalized','trg_notify_hr_new_application']) assert.ok(migration.includes(trigger), `missing trigger ${trigger}`);
  assert.match(migration, /security definer/i);
  assert.match(migration, /revoke execute/i);
});
