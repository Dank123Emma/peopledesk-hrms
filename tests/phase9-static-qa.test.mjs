import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile, readdir, access } from 'node:fs/promises';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { join } from 'node:path';
const execFileAsync = promisify(execFile);
const root = new URL('../', import.meta.url);
const path = (p) => new URL(p, root).pathname;

test('all application JavaScript files pass syntax validation', async () => {
  const dir = path('js/');
  const files = (await readdir(dir)).filter(x => x.endsWith('.js'));
  assert.ok(files.length >= 4);
  for (const file of files) await execFileAsync('node', ['--check', join(dir,file)]);
});

test('all local HTML assets exist', async () => {
  const html = await readFile(path('index.html'),'utf8');
  const refs = [...html.matchAll(/(?:src|href)="([^" ]+)"/g)].map(x=>x[1]).filter(x=>!/^https?:|^\/\//.test(x));
  for (const ref of refs) await access(path(ref));
});

test('all numbered migrations are present and wrapped transactionally', async () => {
  const dir = path('database/migrations');
  const files = (await readdir(dir)).filter(x=>x.endsWith('.sql')).sort();
  assert.equal(files.length,7);
  for (const file of files) {
    const sql = (await readFile(join(dir,file),'utf8')).trim();
    assert.match(sql,/\bbegin;\s/i,`${file} should begin a transaction`);
    assert.match(sql,/\bcommit;\s*(?:--[^\n]*\s*)*$/i,`${file} should commit`);
  }
});

test('migrations do not contain destructive table drops', async () => {
  const dir = path('database/migrations');
  for (const file of await readdir(dir)) if (file.endsWith('.sql')) {
    const sql = await readFile(join(dir,file),'utf8');
    assert.doesNotMatch(sql,/\bdrop\s+table\b/i,`${file} contains DROP TABLE`);
  }
});

test('phase 8 notification triggers and reports remain included', async () => {
  const sql = await readFile(path('database/migrations/20261119_phase8_reports_notifications.sql'),'utf8');
  const app = await readFile(path('js/app.js'),'utf8');
  for (const name of ['trg_notify_leave_decision','trg_notify_training_request','trg_notify_payroll_status','trg_notify_appraisal_finalized','trg_notify_hr_new_application']) assert.ok(sql.includes(name));
  for (const metric of ['Active workforce','Attendance today','Pending leave','Training completion','Open vacancies','Latest payroll','Appraisals','Succession plans']) assert.ok(app.includes(metric));
});
