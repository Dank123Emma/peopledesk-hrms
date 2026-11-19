-- PeopleDesk HRMS: Supabase PostgreSQL schema
create extension if not exists pgcrypto;

create type public.app_role as enum ('administrator','hr','manager','payroll','employee');
create type public.record_status as enum ('Pending','Approved','Rejected','Cancelled');

create table public.departments (
 id uuid primary key default gen_random_uuid(),
 name text not null unique,
 created_at timestamptz not null default now()
);
create table public.positions (
 id uuid primary key default gen_random_uuid(),
 department_id uuid references public.departments(id),
 title text not null,
 created_at timestamptz not null default now(),
 unique(department_id,title)
);
create table public.employees (
 id uuid primary key default gen_random_uuid(),
 employee_id text not null unique,
 full_name text not null,
 gender text check (gender in ('Female','Male','Other','Prefer not to say')),
 date_of_birth date,
 email text unique,
 phone text,
 residential_address text,
 department text,
 position text,
 department_id uuid references public.departments(id),
 position_id uuid references public.positions(id),
 employment_date date not null,
 employment_status text not null default 'Active',
 employment_type text default 'Permanent',
 basic_salary numeric(12,2) not null default 0 check (basic_salary >= 0),
 emergency_contact_name text,
 emergency_contact_phone text,
 emergency_contact_relationship text,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create table public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 employee_id uuid unique references public.employees(id),
 full_name text not null,
 role public.app_role not null default 'employee',
 department text,
 is_active boolean not null default true,
 created_at timestamptz not null default now()
);
create table public.shifts (
 id uuid primary key default gen_random_uuid(),
 name text not null,
 start_time time not null,
 end_time time not null,
 grace_period_minutes integer not null default 10 check(grace_period_minutes between 0 and 240),
 active boolean not null default true
);
create table public.holidays (
 id uuid primary key default gen_random_uuid(),
 holiday_date date not null unique,
 name text not null
);
create table public.attendance_records (
 id uuid primary key default gen_random_uuid(),
 employee_id uuid not null references public.employees(id),
 work_date date not null,
 clock_in timestamptz,
 clock_out timestamptz,
 status text not null default 'Present' check(status in ('Present','Late','Absent','On Leave','Incomplete')),
 correction_reason text,
 corrected_by uuid references auth.users(id),
 created_at timestamptz not null default now(),
 unique(employee_id,work_date),
 check(clock_out is null or clock_in is not null),
 check(clock_out is null or clock_out >= clock_in)
);
create table public.leave_types (
 id uuid primary key default gen_random_uuid(),
 name text not null unique,
 annual_entitlement numeric(6,2) not null default 0,
 requires_document boolean not null default false
);
create table public.leave_balances (
 id uuid primary key default gen_random_uuid(),
 employee_id uuid not null references public.employees(id),
 leave_type_id uuid not null references public.leave_types(id),
 entitlement numeric(6,2) not null default 0,
 used_days numeric(6,2) not null default 0,
 unique(employee_id,leave_type_id)
);
create table public.leave_applications (
 id uuid primary key default gen_random_uuid(),
 employee_id uuid not null references public.employees(id),
 leave_type text not null,
 start_date date not null,
 end_date date not null,
 days numeric(6,2) not null check(days > 0),
 reason text not null,
 status public.record_status not null default 'Pending',
 decision_reason text,
 approved_by uuid references auth.users(id),
 approved_at timestamptz,
 created_at timestamptz not null default now(),
 check(end_date >= start_date)
);
create table public.training_needs (
 id uuid primary key default gen_random_uuid(),
 employee_id uuid not null references public.employees(id),
 title text not null,
 category text,
 reason text,
 start_date date,
 end_date date,
 status text not null default 'Pending',
 created_at timestamptz not null default now()
);
create table public.training_programmes (
 id uuid primary key default gen_random_uuid(),
 title text not null,
 description text,
 trainer text,
 venue text,
 start_date date,
 end_date date,
 budget numeric(12,2) default 0,
 status text not null default 'Planned',
 created_at timestamptz not null default now()
);
create table public.training_participants (
 id uuid primary key default gen_random_uuid(),
 programme_id uuid not null references public.training_programmes(id) on delete cascade,
 employee_id uuid not null references public.employees(id),
 attendance_status text default 'Registered',
 completion_status text default 'Pending',
 unique(programme_id,employee_id)
);
create table public.training_evaluations (
 id uuid primary key default gen_random_uuid(),
 participant_id uuid not null references public.training_participants(id),
 pre_score numeric(5,2),
 post_score numeric(5,2),
 employee_feedback text,
 trainer_feedback text,
 effectiveness_score numeric(5,2),
 evaluated_at timestamptz default now()
);
create table public.appraisal_periods (
 id uuid primary key default gen_random_uuid(),
 name text not null,
 start_date date not null,
 end_date date not null,
 status text not null default 'Draft'
);
create table public.appraisal_criteria (
 id uuid primary key default gen_random_uuid(),
 name text not null,
 weight numeric(5,2) not null default 1 check(weight > 0),
 active boolean not null default true
);
create table public.performance_appraisals (
 id uuid primary key default gen_random_uuid(),
 employee_id uuid not null references public.employees(id),
 period_id uuid not null references public.appraisal_periods(id),
 manager_id uuid references public.profiles(id),
 overall_score numeric(5,2),
 comments text,
 strengths text,
 improvement_plan text,
 status text not null default 'Draft',
 finalized_at timestamptz,
 created_at timestamptz not null default now(),
 unique(employee_id,period_id)
);
create table public.appraisal_scores (
 id uuid primary key default gen_random_uuid(),
 appraisal_id uuid not null references public.performance_appraisals(id) on delete cascade,
 criterion_id uuid not null references public.appraisal_criteria(id),
 score numeric(4,2) not null check(score between 1 and 5),
 comment text,
 unique(appraisal_id,criterion_id)
);
create table public.salary_structures (
 id uuid primary key default gen_random_uuid(),
 employee_id uuid not null references public.employees(id),
 basic_salary numeric(12,2) not null check(basic_salary >= 0),
 effective_from date not null,
 effective_to date,
 created_at timestamptz not null default now()
);
create table public.payroll_periods (
 id uuid primary key default gen_random_uuid(),
 period_month date not null unique,
 status text not null default 'Draft',
 approved_by uuid references auth.users(id),
 approved_at timestamptz,
 paid_at timestamptz
);
create table public.payroll_records (
 id uuid primary key default gen_random_uuid(),
 employee_id uuid not null references public.employees(id),
 payroll_period date not null,
 basic_salary numeric(12,2) not null default 0,
 total_earnings numeric(12,2) not null default 0,
 total_deductions numeric(12,2) not null default 0,
 net_salary numeric(12,2) generated always as (total_earnings-total_deductions) stored,
 status text not null default 'Draft',
 created_at timestamptz not null default now(),
 unique(employee_id,payroll_period),
 check(total_earnings >= 0 and total_deductions >= 0 and total_deductions <= total_earnings)
);
create table public.payroll_items (
 id uuid primary key default gen_random_uuid(),
 payroll_record_id uuid not null references public.payroll_records(id) on delete cascade,
 item_type text not null check(item_type in ('Earning','Deduction')),
 description text not null,
 amount numeric(12,2) not null check(amount >= 0)
);
create table public.succession_plans (
 id uuid primary key default gen_random_uuid(),
 position text not null,
 incumbent text,
 successor text,
 expected_transition_date date,
 training_status text,
 readiness text,
 vacancy text,
 notes text,
 created_at timestamptz not null default now()
);
create table public.recruitment_applications (
 id uuid primary key default gen_random_uuid(),
 applicant_name text not null,
 position text not null,
 application_date date not null default current_date,
 contact_email text,
 contact_phone text,
 status text not null default 'Received',
 interview_status text,
 remarks text,
 created_at timestamptz not null default now()
);
create table public.notifications (
 id uuid primary key default gen_random_uuid(),
 user_id uuid references auth.users(id),
 title text not null,
 message text not null,
 read_at timestamptz,
 created_at timestamptz not null default now()
);
create table public.audit_logs (
 id bigint generated always as identity primary key,
 actor_id uuid references auth.users(id),
 action text not null,
 table_name text not null,
 record_id text,
 details jsonb not null default '{}'::jsonb,
 created_at timestamptz not null default now()
);
create table public.system_settings (
 key text primary key,
 value jsonb not null,
 updated_at timestamptz not null default now()
);

create index employees_department_idx on public.employees(department);
create index attendance_work_date_idx on public.attendance_records(work_date);
create index leave_status_idx on public.leave_applications(status);
create index payroll_period_idx on public.payroll_records(payroll_period);

create or replace function public.current_user_role()
returns public.app_role language sql stable security definer set search_path=public
as $$ select role from public.profiles where id=auth.uid() and is_active=true $$;

create or replace function public.is_hr_or_admin()
returns boolean language sql stable security definer set search_path=public
as $$ select coalesce(public.current_user_role() in ('administrator','hr'),false) $$;

create or replace function public.set_updated_at()
returns trigger language plpgsql as $$ begin new.updated_at=now(); return new; end $$;
create trigger employees_updated_at before update on public.employees for each row execute function public.set_updated_at();

-- RLS: deny by default, then grant only the minimum required access.
alter table public.profiles enable row level security;
alter table public.employees enable row level security;
alter table public.departments enable row level security;
alter table public.positions enable row level security;
alter table public.attendance_records enable row level security;
alter table public.leave_applications enable row level security;
alter table public.training_needs enable row level security;
alter table public.training_programmes enable row level security;
alter table public.training_participants enable row level security;
alter table public.training_evaluations enable row level security;
alter table public.performance_appraisals enable row level security;
alter table public.appraisal_scores enable row level security;
alter table public.salary_structures enable row level security;
alter table public.payroll_records enable row level security;
alter table public.payroll_items enable row level security;
alter table public.succession_plans enable row level security;
alter table public.recruitment_applications enable row level security;
alter table public.notifications enable row level security;
alter table public.audit_logs enable row level security;
alter table public.leave_types enable row level security;
alter table public.leave_balances enable row level security;
alter table public.payroll_periods enable row level security;
alter table public.shifts enable row level security;
alter table public.holidays enable row level security;
alter table public.appraisal_periods enable row level security;
alter table public.appraisal_criteria enable row level security;
alter table public.system_settings enable row level security;

create policy "profile self or admin read" on public.profiles for select to authenticated
using (id=auth.uid() or public.current_user_role()='administrator');
create policy "hr manages profiles" on public.profiles for all to authenticated
using (public.current_user_role() in ('administrator','hr')) with check (public.current_user_role() in ('administrator','hr'));

create policy "employees read permitted" on public.employees for select to authenticated
using (public.is_hr_or_admin() or id=(select employee_id from public.profiles where id=auth.uid()) or (public.current_user_role()='manager' and department=(select department from public.profiles where id=auth.uid())));
create policy "hr manages employees" on public.employees for all to authenticated
using (public.current_user_role() in ('administrator','hr')) with check (public.current_user_role() in ('administrator','hr'));

create policy "attendance read scoped" on public.attendance_records for select to authenticated
using (public.is_hr_or_admin() or employee_id=(select employee_id from public.profiles where id=auth.uid()) or (public.current_user_role()='manager' and employee_id in (select id from public.employees where department=(select department from public.profiles where id=auth.uid()))));
create policy "employee creates own attendance" on public.attendance_records for insert to authenticated
with check (employee_id=(select employee_id from public.profiles where id=auth.uid()) or public.is_hr_or_admin());
create policy "hr updates attendance" on public.attendance_records for update to authenticated
using (public.is_hr_or_admin()) with check (public.is_hr_or_admin());

create policy "leave read scoped" on public.leave_applications for select to authenticated
using (public.is_hr_or_admin() or employee_id=(select employee_id from public.profiles where id=auth.uid()) or public.current_user_role()='manager');
create policy "employee submits leave" on public.leave_applications for insert to authenticated
with check (employee_id=(select employee_id from public.profiles where id=auth.uid()) or public.is_hr_or_admin());
create policy "hr or manager decides leave" on public.leave_applications for update to authenticated
using (public.current_user_role() in ('administrator','hr','manager')) with check (public.current_user_role() in ('administrator','hr','manager'));

create policy "hr manages training needs" on public.training_needs for all to authenticated
using (public.current_user_role() in ('administrator','hr','manager')) with check (public.current_user_role() in ('administrator','hr','manager'));
create policy "training read" on public.training_programmes for select to authenticated using (true);
create policy "hr manages programmes" on public.training_programmes for all to authenticated
using (public.current_user_role() in ('administrator','hr')) with check (public.current_user_role() in ('administrator','hr'));
create policy "participants read" on public.training_participants for select to authenticated using (true);
create policy "hr manages participants" on public.training_participants for all to authenticated
using (public.current_user_role() in ('administrator','hr')) with check (public.current_user_role() in ('administrator','hr'));
create policy "evaluations hr" on public.training_evaluations for all to authenticated
using (public.current_user_role() in ('administrator','hr','manager')) with check (public.current_user_role() in ('administrator','hr','manager'));

create policy "appraisals scoped" on public.performance_appraisals for select to authenticated
using (public.is_hr_or_admin() or employee_id=(select employee_id from public.profiles where id=auth.uid()) or manager_id=auth.uid());
create policy "managers create appraisals" on public.performance_appraisals for insert to authenticated
with check (public.current_user_role() in ('administrator','hr','manager'));
create policy "hr updates appraisals" on public.performance_appraisals for update to authenticated
using (public.current_user_role() in ('administrator','hr')) with check (public.current_user_role() in ('administrator','hr'));
create policy "appraisal scores scoped" on public.appraisal_scores for select to authenticated using (true);
create policy "managers manage scores" on public.appraisal_scores for all to authenticated
using (public.current_user_role() in ('administrator','hr','manager')) with check (public.current_user_role() in ('administrator','hr','manager'));

create policy "payroll records restricted" on public.payroll_records for select to authenticated
using (public.current_user_role() in ('administrator','hr','payroll') or employee_id=(select employee_id from public.profiles where id=auth.uid()));
create policy "payroll officers manage records" on public.payroll_records for all to authenticated
using (public.current_user_role() in ('administrator','payroll')) with check (public.current_user_role() in ('administrator','payroll'));
create policy "salary structure restricted" on public.salary_structures for select to authenticated
using (public.current_user_role() in ('administrator','hr','payroll') or employee_id=(select employee_id from public.profiles where id=auth.uid()));
create policy "payroll roles manage salary" on public.salary_structures for all to authenticated
using (public.current_user_role() in ('administrator','payroll')) with check (public.current_user_role() in ('administrator','payroll'));
create policy "payroll items restricted" on public.payroll_items for select to authenticated
using (exists(select 1 from public.payroll_records p where p.id=payroll_record_id));
create policy "payroll officers manage items" on public.payroll_items for all to authenticated
using (public.current_user_role() in ('administrator','payroll')) with check (public.current_user_role() in ('administrator','payroll'));

create policy "hr manages succession" on public.succession_plans for all to authenticated
using (public.current_user_role() in ('administrator','hr','manager')) with check (public.current_user_role() in ('administrator','hr','manager'));
create policy "hr manages recruitment" on public.recruitment_applications for all to authenticated
using (public.current_user_role() in ('administrator','hr')) with check (public.current_user_role() in ('administrator','hr'));
create policy "notifications own" on public.notifications for select to authenticated using (user_id=auth.uid());
create policy "notifications update own" on public.notifications for update to authenticated using (user_id=auth.uid()) with check(user_id=auth.uid());
create policy "audit admin read" on public.audit_logs for select to authenticated using(public.current_user_role()='administrator');
create policy "audit insert authenticated" on public.audit_logs for insert to authenticated with check(actor_id=auth.uid());
create policy "departments read" on public.departments for select to authenticated using(true);
create policy "positions read" on public.positions for select to authenticated using(true);
create policy "hr manages org structure" on public.departments for all to authenticated using(public.current_user_role() in ('administrator','hr')) with check(public.current_user_role() in ('administrator','hr'));
create policy "hr manages positions" on public.positions for all to authenticated using(public.current_user_role() in ('administrator','hr')) with check(public.current_user_role() in ('administrator','hr'));

-- Seed organization leave types. Add employees through the authenticated HR interface.
insert into public.leave_types(name,annual_entitlement,requires_document) values
('Annual',21,false),('Sick',10,true),('Maternity',90,true),('Casual',5,false)
on conflict(name) do nothing;
insert into public.system_settings(key,value) values
('organization_timezone','"Africa/Accra"'),
('currency','"GHS"'),
('attendance_policy','{"start_time":"08:00","end_time":"17:00","grace_period_minutes":10}'),
('retirement_policy','{"retirement_age":60}')
on conflict(key) do nothing;
