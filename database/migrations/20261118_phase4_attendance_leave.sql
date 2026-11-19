-- PeopleDesk HRMS Phase 4: attendance and leave workflows.
-- Apply after schema.sql and the Phase 1/Phase 3 migrations.
-- Uses transactional SECURITY DEFINER RPCs so calculations and approvals cannot
-- be bypassed by direct browser writes. No existing business records are deleted.

begin;

-- Per-employee shift assignment with effective dates.
create table if not exists public.employee_shift_assignments (
  id uuid primary key default gen_random_uuid(),
  employee_id uuid not null references public.employees(id) on delete cascade,
  shift_id uuid not null references public.shifts(id),
  effective_from date not null,
  effective_to date,
  created_at timestamptz not null default now(),
  check (effective_to is null or effective_to >= effective_from)
);
create index if not exists employee_shift_assignments_lookup_idx
  on public.employee_shift_assignments(employee_id, effective_from desc);
alter table public.employee_shift_assignments enable row level security;
grant select, insert, update, delete on public.employee_shift_assignments to authenticated;

drop policy if exists employee_shift_assignments_read_scoped on public.employee_shift_assignments;
drop policy if exists employee_shift_assignments_manage_hr on public.employee_shift_assignments;
create policy employee_shift_assignments_read_scoped on public.employee_shift_assignments
for select to authenticated
using (public.can_access_employee(employee_id));
create policy employee_shift_assignments_manage_hr on public.employee_shift_assignments
for all to authenticated
using (public.is_hr_or_admin()) with check (public.is_hr_or_admin());

-- Direct inserts/updates to workflow-controlled fields are disabled. The RPCs below
-- validate the caller and make the related records/balance updates atomically.
drop policy if exists attendance_insert_self on public.attendance_records;
drop policy if exists leave_insert_self on public.leave_applications;
drop policy if exists leave_update_hr on public.leave_applications;
drop policy if exists leave_update_manager_department on public.leave_applications;

create or replace function public.attendance_clock_in()
returns public.attendance_records
language plpgsql
security definer
set search_path = pg_catalog, public
set row_security = off
as $$
declare
  v_employee_id uuid;
  v_work_date date;
  v_now timestamptz := clock_timestamp();
  v_status text := 'Present';
  v_shift record;
  v_scheduled_start timestamptz;
  v_record public.attendance_records;
begin
  select p.employee_id into v_employee_id
  from public.profiles p
  where p.id = (select auth.uid()) and p.is_active = true;
  if v_employee_id is null then
    raise exception 'Your active account is not linked to an employee record.' using errcode = '42501';
  end if;

  v_work_date := (v_now at time zone 'Africa/Accra')::date;
  select s.start_time, s.grace_period_minutes
    into v_shift
  from public.employee_shift_assignments a
  join public.shifts s on s.id = a.shift_id and s.active = true
  where a.employee_id = v_employee_id
    and a.effective_from <= v_work_date
    and (a.effective_to is null or a.effective_to >= v_work_date)
  order by a.effective_from desc, a.created_at desc
  limit 1;

  if found then
    v_scheduled_start := (v_work_date + v_shift.start_time) at time zone 'Africa/Accra';
    if v_now > v_scheduled_start + make_interval(mins => v_shift.grace_period_minutes) then
      v_status := 'Late';
    end if;
  end if;

  insert into public.attendance_records(employee_id, work_date, clock_in, status)
  values (v_employee_id, v_work_date, v_now, v_status)
  returning * into v_record;

  insert into public.audit_logs(actor_id, action, table_name, record_id, details)
  values ((select auth.uid()), 'clock_in', 'attendance_records', v_record.id::text,
          jsonb_build_object('work_date', v_work_date, 'status', v_status));
  return v_record;
exception
  when unique_violation then
    raise exception 'A clock-in record already exists for today.' using errcode = '23505';
end;
$$;

create or replace function public.attendance_clock_out()
returns public.attendance_records
language plpgsql
security definer
set search_path = pg_catalog, public
set row_security = off
as $$
declare
  v_employee_id uuid;
  v_work_date date;
  v_record public.attendance_records;
begin
  select p.employee_id into v_employee_id
  from public.profiles p
  where p.id = (select auth.uid()) and p.is_active = true;
  if v_employee_id is null then
    raise exception 'Your active account is not linked to an employee record.' using errcode = '42501';
  end if;

  v_work_date := (clock_timestamp() at time zone 'Africa/Accra')::date;
  update public.attendance_records
     set clock_out = clock_timestamp()
   where employee_id = v_employee_id
     and work_date = v_work_date
     and clock_in is not null
     and clock_out is null
  returning * into v_record;

  if not found then
    raise exception 'No open clock-in was found for today, or you have already clocked out.' using errcode = 'P0002';
  end if;

  insert into public.audit_logs(actor_id, action, table_name, record_id, details)
  values ((select auth.uid()), 'clock_out', 'attendance_records', v_record.id::text,
          jsonb_build_object('work_date', v_work_date, 'clock_out', v_record.clock_out));
  return v_record;
end;
$$;

create or replace function public.submit_leave_application(
  p_leave_type text,
  p_start_date date,
  p_end_date date,
  p_reason text
)
returns public.leave_applications
language plpgsql
security definer
set search_path = pg_catalog, public
set row_security = off
as $$
declare
  v_employee_id uuid;
  v_leave_type public.leave_types;
  v_days numeric(6,2);
  v_entitlement numeric(6,2);
  v_used numeric(6,2);
  v_application public.leave_applications;
begin
  select p.employee_id into v_employee_id
  from public.profiles p
  where p.id = (select auth.uid()) and p.is_active = true;
  if v_employee_id is null then
    raise exception 'Your active account is not linked to an employee record.' using errcode = '42501';
  end if;
  if p_leave_type is null or btrim(p_leave_type) = '' or p_reason is null or btrim(p_reason) = '' then
    raise exception 'Leave type and reason are required.' using errcode = '22023';
  end if;
  if p_start_date is null or p_end_date is null or p_end_date < p_start_date then
    raise exception 'Enter a valid leave date range.' using errcode = '22023';
  end if;
  if p_start_date < (clock_timestamp() at time zone 'Africa/Accra')::date then
    raise exception 'Leave applications cannot start in the past.' using errcode = '22023';
  end if;

  select * into v_leave_type from public.leave_types where lower(name) = lower(btrim(p_leave_type)) limit 1;
  if not found then
    raise exception 'The selected leave type is not configured. Contact HR.' using errcode = '22023';
  end if;
  if v_leave_type.requires_document then
    raise exception 'This leave type requires supporting documentation. Please submit it through HR until document upload is enabled.' using errcode = '22023';
  end if;

  select count(*)::numeric(6,2) into v_days
  from generate_series(p_start_date, p_end_date, interval '1 day') d(day_value)
  where extract(isodow from d.day_value) between 1 and 5
    and not exists (select 1 from public.holidays h where h.holiday_date = d.day_value::date);
  if v_days <= 0 then
    raise exception 'The selected date range contains no working days.' using errcode = '22023';
  end if;

  if exists (
    select 1 from public.leave_applications la
    where la.employee_id = v_employee_id
      and la.status in ('Pending','Approved')
      and daterange(la.start_date, la.end_date, '[]') && daterange(p_start_date, p_end_date, '[]')
  ) then
    raise exception 'The requested dates overlap an existing pending or approved leave application.' using errcode = '23P01';
  end if;

  insert into public.leave_balances(employee_id, leave_type_id, entitlement, used_days)
  values (v_employee_id, v_leave_type.id, v_leave_type.annual_entitlement, 0)
  on conflict (employee_id, leave_type_id) do nothing;

  select lb.entitlement, lb.used_days into v_entitlement, v_used
  from public.leave_balances lb
  where lb.employee_id = v_employee_id and lb.leave_type_id = v_leave_type.id
  for update;
  if v_days > greatest(v_entitlement - v_used, 0) then
    raise exception 'Insufficient leave balance. Available: % day(s); requested: % day(s).',
      greatest(v_entitlement - v_used, 0), v_days using errcode = '22023';
  end if;

  insert into public.leave_applications(employee_id, leave_type, start_date, end_date, days, reason, status)
  values (v_employee_id, v_leave_type.name, p_start_date, p_end_date, v_days, btrim(p_reason), 'Pending')
  returning * into v_application;

  insert into public.audit_logs(actor_id, action, table_name, record_id, details)
  values ((select auth.uid()), 'submit_leave', 'leave_applications', v_application.id::text,
          jsonb_build_object('leave_type', v_leave_type.name, 'days', v_days));
  return v_application;
end;
$$;

create or replace function public.decide_leave_application(
  p_application_id uuid,
  p_decision text,
  p_decision_reason text default null
)
returns public.leave_applications
language plpgsql
security definer
set search_path = pg_catalog, public
set row_security = off
as $$
declare
  v_role public.app_role;
  v_employee_id uuid;
  v_leave_type_id uuid;
  v_application public.leave_applications;
  v_balance public.leave_balances;
begin
  select p.role into v_role
  from public.profiles p
  where p.id = (select auth.uid()) and p.is_active = true;
  if v_role is null or v_role not in ('administrator','hr','manager') then
    raise exception 'You are not authorized to decide leave applications.' using errcode = '42501';
  end if;
  if p_decision is null or p_decision not in ('Approved','Rejected') then
    raise exception 'Decision must be Approved or Rejected.' using errcode = '22023';
  end if;

  select * into v_application
  from public.leave_applications
  where id = p_application_id
  for update;
  if not found then raise exception 'Leave application not found.' using errcode = 'P0002'; end if;
  if v_application.status <> 'Pending' then
    raise exception 'Only pending leave applications can be decided.' using errcode = '22023';
  end if;
  if v_role = 'manager' and not public.can_access_employee(v_application.employee_id) then
    raise exception 'You can only decide leave applications for your department.' using errcode = '42501';
  end if;

  if p_decision = 'Approved' then
    select lt.id into v_leave_type_id
    from public.leave_types lt where lower(lt.name) = lower(v_application.leave_type) limit 1;
    if v_leave_type_id is null then raise exception 'The leave type is no longer configured.' using errcode = '22023'; end if;

    insert into public.leave_balances(employee_id, leave_type_id, entitlement, used_days)
    select v_application.employee_id, lt.id, lt.annual_entitlement, 0
    from public.leave_types lt where lt.id = v_leave_type_id
    on conflict (employee_id, leave_type_id) do nothing;

    select * into v_balance from public.leave_balances
    where employee_id = v_application.employee_id and leave_type_id = v_leave_type_id
    for update;
    if v_application.days > greatest(v_balance.entitlement - v_balance.used_days, 0) then
      raise exception 'Insufficient remaining leave balance to approve this request.' using errcode = '22023';
    end if;

    update public.leave_balances
       set used_days = used_days + v_application.days
     where id = v_balance.id;
  end if;

  update public.leave_applications
     set status = p_decision::public.record_status,
         decision_reason = nullif(btrim(coalesce(p_decision_reason,'')),''),
         approved_by = (select auth.uid()),
         approved_at = clock_timestamp()
   where id = p_application_id
  returning * into v_application;

  insert into public.audit_logs(actor_id, action, table_name, record_id, details)
  values ((select auth.uid()), 'leave_' || lower(p_decision), 'leave_applications', v_application.id::text,
          jsonb_build_object('employee_id', v_application.employee_id, 'decision_reason', v_application.decision_reason));
  return v_application;
end;
$$;

revoke all on function public.attendance_clock_in() from public, anon;
revoke all on function public.attendance_clock_out() from public, anon;
revoke all on function public.submit_leave_application(text,date,date,text) from public, anon;
revoke all on function public.decide_leave_application(uuid,text,text) from public, anon;
grant execute on function public.attendance_clock_in() to authenticated;
grant execute on function public.attendance_clock_out() to authenticated;
grant execute on function public.submit_leave_application(text,date,date,text) to authenticated;
grant execute on function public.decide_leave_application(uuid,text,text) to authenticated;

commit;
