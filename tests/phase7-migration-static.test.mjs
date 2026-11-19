import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
const sql = readFileSync(new URL('../database/migrations/20261119_phase7_recruitment_succession.sql', import.meta.url), 'utf8');
for (const token of [
  'create table if not exists public.job_vacancies',
  'create table if not exists public.recruitment_interviews',
  'create table if not exists public.succession_development_actions',
  'approve_job_vacancy',
  'enforce_vacancy_approval',
  'recruitment_applications_hr_manage',
  'succession_plans_read_scoped',
  'succession_actions_manage_hr',
  'begin;', 'commit;'
]) assert.ok(sql.toLowerCase().includes(token.toLowerCase()), `Missing SQL migration token: ${token}`);
console.log('PeopleDesk Phase 7 migration static checks passed.');
