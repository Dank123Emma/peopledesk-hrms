-- PeopleDesk HRMS Phase 7: Recruitment and succession planning
-- Additive migration. Existing application records are preserved.
begin;

create table if not exists public.job_vacancies (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  department text,
  position text,
  job_description text not null,
  requirements text,
  employment_type text not null default 'Permanent',
  location text,
  opening_date date not null default current_date,
  closing_date date,
  status text not null default 'Draft' check(status in ('Draft','Pending Approval','Open','Closed','Cancelled')),
  approved_by uuid references auth.users(id),
  approved_at timestamptz,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check(closing_date is null or closing_date >= opening_date)
);

alter table public.recruitment_applications
  add column if not exists vacancy_id uuid references public.job_vacancies(id) on delete set null,
  add column if not exists stage text not null default 'Received',
  add column if not exists shortlist_reason text,
  add column if not exists evaluation_score numeric(5,2),
  add column if not exists updated_at timestamptz not null default now();

create table if not exists public.recruitment_interviews (
  id uuid primary key default gen_random_uuid(),
  application_id uuid not null references public.recruitment_applications(id) on delete cascade,
  scheduled_at timestamptz not null,
  interview_type text not null default 'Panel',
  location text,
  panel_members text[] not null default '{}',
  score numeric(5,2) check(score is null or score between 0 and 100),
  outcome text not null default 'Pending' check(outcome in ('Pending','Pass','Fail','Reschedule')),
  notes text,
  interviewer_id uuid references auth.users(id),
  created_at timestamptz not null default now()
);

alter table public.succession_plans
  add column if not exists department text,
  add column if not exists incumbent_employee_id uuid references public.employees(id) on delete set null,
  add column if not exists successor_employee_id uuid references public.employees(id) on delete set null,
  add column if not exists risk_level text not null default 'Medium' check(risk_level in ('Low','Medium','High','Critical')),
  add column if not exists development_plan text,
  add column if not exists readiness_assessed_at timestamptz,
  add column if not exists updated_at timestamptz not null default now();

create table if not exists public.succession_development_actions (
  id uuid primary key default gen_random_uuid(),
  succession_plan_id uuid not null references public.succession_plans(id) on delete cascade,
  action_title text not null,
  description text,
  owner_employee_id uuid references public.employees(id) on delete set null,
  due_date date,
  status text not null default 'Planned' check(status in ('Planned','In Progress','Completed','Cancelled')),
  completed_at timestamptz,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);

create index if not exists job_vacancies_status_dates_idx on public.job_vacancies(status,opening_date,closing_date);
create index if not exists recruitment_applications_vacancy_idx on public.recruitment_applications(vacancy_id);
create index if not exists recruitment_applications_stage_idx on public.recruitment_applications(stage);
create index if not exists recruitment_interviews_application_idx on public.recruitment_interviews(application_id,scheduled_at);
create index if not exists succession_plans_department_idx on public.succession_plans(department);
create index if not exists succession_actions_plan_idx on public.succession_development_actions(succession_plan_id,status);

alter table public.job_vacancies enable row level security;
alter table public.recruitment_interviews enable row level security;
alter table public.succession_development_actions enable row level security;

-- Replace the older manager-wide succession write policy. Managers may read
-- succession plans for their department; HR/Admin manage plans and actions.
drop policy if exists "hr manages succession" on public.succession_plans;
drop policy if exists succession_read_hr_manager on public.succession_plans;
drop policy if exists succession_manage_hr on public.succession_plans;
drop policy if exists succession_plans_read_scoped on public.succession_plans;
drop policy if exists succession_plans_manage_hr on public.succession_plans;
create policy succession_plans_read_scoped on public.succession_plans for select to authenticated
using (public.current_user_role() in ('administrator','hr') or
  (public.current_user_role()='manager' and department=(select department from public.profiles where id=auth.uid())));
create policy succession_plans_manage_hr on public.succession_plans for all to authenticated
using (public.current_user_role() in ('administrator','hr'))
with check (public.current_user_role() in ('administrator','hr'));

drop policy if exists job_vacancies_read_hr_manager on public.job_vacancies;
drop policy if exists job_vacancies_manage_hr on public.job_vacancies;
create policy job_vacancies_read_hr_manager on public.job_vacancies for select to authenticated
using (public.current_user_role() in ('administrator','hr','manager'));
create policy job_vacancies_manage_hr on public.job_vacancies for all to authenticated
using (public.current_user_role() in ('administrator','hr'))
with check (public.current_user_role() in ('administrator','hr'));

create or replace function public.approve_job_vacancy(p_vacancy_id uuid)
returns public.job_vacancies
language plpgsql
security definer
set search_path=public
as $$
declare result public.job_vacancies;
begin
  if public.current_user_role() is distinct from 'administrator' then
    raise exception 'Only an administrator can approve vacancies.' using errcode='42501';
  end if;
  update public.job_vacancies
    set status='Open', approved_by=auth.uid(), approved_at=now(), updated_at=now()
    where id=p_vacancy_id and status='Pending Approval'
    returning * into result;
  if result.id is null then
    raise exception 'Vacancy not found or not pending approval.' using errcode='P0002';
  end if;
  return result;
end;
$$;
grant execute on function public.approve_job_vacancy(uuid) to authenticated;

create or replace function public.enforce_vacancy_approval()
returns trigger
language plpgsql
security invoker
set search_path=public
as $$
begin
  if new.status='Open' then
    if tg_op='INSERT' then
      if public.current_user_role() is distinct from 'administrator' or new.approved_by is distinct from auth.uid() then
        raise exception 'Vacancies must be approved by an administrator before opening.' using errcode='42501';
      end if;
    elsif old.status is distinct from new.status then
      if public.current_user_role() is distinct from 'administrator' or new.approved_by is distinct from auth.uid() then
        raise exception 'Vacancies must be approved by an administrator before opening.' using errcode='42501';
      end if;
    end if;
  end if;
  return new;
end;
$$;
drop trigger if exists job_vacancy_approval_guard on public.job_vacancies;
create trigger job_vacancy_approval_guard before insert or update on public.job_vacancies
for each row execute function public.enforce_vacancy_approval();

-- Candidate data is confidential and accessible only to HR/Admin.
drop policy if exists recruitment_read_hr on public.recruitment_applications;
drop policy if exists recruitment_manage_hr on public.recruitment_applications;
drop policy if exists "hr manages recruitment" on public.recruitment_applications;
create policy recruitment_applications_hr_read on public.recruitment_applications for select to authenticated
using (public.current_user_role() in ('administrator','hr'));
create policy recruitment_applications_hr_manage on public.recruitment_applications for all to authenticated
using (public.current_user_role() in ('administrator','hr'))
with check (public.current_user_role() in ('administrator','hr'));

drop policy if exists recruitment_interviews_hr_read on public.recruitment_interviews;
drop policy if exists recruitment_interviews_hr_manage on public.recruitment_interviews;
create policy recruitment_interviews_hr_read on public.recruitment_interviews for select to authenticated
using (public.current_user_role() in ('administrator','hr'));
create policy recruitment_interviews_hr_manage on public.recruitment_interviews for all to authenticated
using (public.current_user_role() in ('administrator','hr'))
with check (public.current_user_role() in ('administrator','hr'));

drop policy if exists succession_actions_read_scoped on public.succession_development_actions;
drop policy if exists succession_actions_manage_hr on public.succession_development_actions;
create policy succession_actions_read_scoped on public.succession_development_actions for select to authenticated
using (public.current_user_role() in ('administrator','hr') or exists(
  select 1 from public.succession_plans sp where sp.id=succession_plan_id
  and public.current_user_role()='manager'
  and sp.department=(select department from public.profiles where id=auth.uid())
));
create policy succession_actions_manage_hr on public.succession_development_actions for all to authenticated
using (public.current_user_role() in ('administrator','hr'))
with check (public.current_user_role() in ('administrator','hr'));

commit;
