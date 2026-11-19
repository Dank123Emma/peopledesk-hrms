-- PeopleDesk HRMS: RLS hardening migration
-- Apply AFTER database/schema.sql to an existing Supabase project.
-- This migration changes policies/functions only; it does not drop or recreate business data.

begin;

-- SECURITY DEFINER helpers read profile/employee relationships without recursively
-- invoking the caller-facing RLS policies. The function owner must be a trusted
-- database owner (as with normal Supabase migrations).
create or replace function public.current_user_role()
returns public.app_role
language sql
stable
security definer
set search_path = pg_catalog, public
set row_security = off
as $$
  select p.role
  from public.profiles p
  where p.id = (select auth.uid())
    and p.is_active = true
  limit 1
$$;

create or replace function public.current_user_employee_id()
returns uuid
language sql
stable
security definer
set search_path = pg_catalog, public
set row_security = off
as $$
  select p.employee_id
  from public.profiles p
  where p.id = (select auth.uid())
    and p.is_active = true
  limit 1
$$;

create or replace function public.is_hr_or_admin()
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
set row_security = off
as $$
  select coalesce(public.current_user_role() in ('administrator','hr'), false)
$$;

create or replace function public.can_access_employee(target_employee_id uuid)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
set row_security = off
as $$
  select coalesce(
    public.current_user_role() in ('administrator','hr')
    or target_employee_id = public.current_user_employee_id()
    or (
      public.current_user_role() = 'manager'
      and exists (
        select 1
        from public.employees e
        join public.profiles manager_profile on manager_profile.id = (select auth.uid())
        where e.id = target_employee_id
          and manager_profile.is_active = true
          and e.department = manager_profile.department
      )
    ),
    false
  )
$$;

create or replace function public.can_access_payroll_employee(target_employee_id uuid)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
set row_security = off
as $$
  select coalesce(
    public.current_user_role() in ('administrator','hr','payroll')
    or target_employee_id = public.current_user_employee_id(),
    false
  )
$$;

create or replace function public.can_access_appraisal(target_appraisal_id uuid)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
set row_security = off
as $$
  select coalesce(
    public.current_user_role() in ('administrator','hr')
    or exists (
      select 1
      from public.performance_appraisals a
      where a.id = target_appraisal_id
        and (
          a.employee_id = public.current_user_employee_id()
          or a.manager_id = (select auth.uid())
          or (
            public.current_user_role() = 'manager'
            and exists (
              select 1 from public.employees e
              join public.profiles mp on mp.id = (select auth.uid())
              where e.id = a.employee_id
                and e.department = mp.department
                and mp.is_active = true
            )
          )
        )
    ),
    false
  )
$$;

revoke all on function public.current_user_role() from public, anon;
revoke all on function public.current_user_employee_id() from public, anon;
revoke all on function public.is_hr_or_admin() from public, anon;
revoke all on function public.can_access_employee(uuid) from public, anon;
revoke all on function public.can_access_payroll_employee(uuid) from public, anon;
revoke all on function public.can_access_appraisal(uuid) from public, anon;
grant execute on function public.current_user_role() to authenticated;
grant execute on function public.current_user_employee_id() to authenticated;
grant execute on function public.is_hr_or_admin() to authenticated;
grant execute on function public.can_access_employee(uuid) to authenticated;
grant execute on function public.can_access_payroll_employee(uuid) to authenticated;
grant execute on function public.can_access_appraisal(uuid) to authenticated;

-- Prevent HR users and ordinary users from assigning privileged roles.
-- SQL-editor/service-role provisioning with no end-user auth.uid() remains possible.
create or replace function public.guard_profile_role_changes()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
set row_security = off
as $$
begin
  if (select auth.uid()) is null then
    return new;
  end if;

  if tg_op = 'INSERT' then
    if public.current_user_role() is distinct from 'administrator'::public.app_role
       and new.role <> 'employee'::public.app_role then
      raise exception 'Only an administrator may create a profile with a privileged role.'
        using errcode = '42501';
    end if;
  elsif new.role is distinct from old.role
        and public.current_user_role() is distinct from 'administrator'::public.app_role then
    raise exception 'Only an administrator may change a profile role.'
      using errcode = '42501';
  end if;

  return new;
end
$$;

drop trigger if exists profiles_guard_role_changes on public.profiles;
create trigger profiles_guard_role_changes
before insert or update of role on public.profiles
for each row execute function public.guard_profile_role_changes();

-- Remove the original permissive/over-broad policies before installing scoped policies.
do $$
declare p record;
begin
  for p in
    select schemaname, tablename, policyname
    from pg_policies
    where schemaname = 'public'
      and tablename = any(array[
        'profiles','employees','departments','positions','attendance_records',
        'leave_applications','training_needs','training_programmes',
        'training_participants','training_evaluations','performance_appraisals',
        'appraisal_scores','salary_structures','payroll_records','payroll_items',
        'succession_plans','recruitment_applications','notifications','audit_logs',
        'leave_types','leave_balances','payroll_periods','shifts','holidays',
        'appraisal_periods','appraisal_criteria','system_settings'
      ])
  loop
    execute format('drop policy if exists %I on %I.%I', p.policyname, p.schemaname, p.tablename);
  end loop;
end
$$;

-- Profiles: users can read themselves; HR/admin can administer profiles.
create policy profiles_read_self_or_hr on public.profiles
for select to authenticated
using (id = (select auth.uid()) or public.is_hr_or_admin());
create policy profiles_insert_hr on public.profiles
for insert to authenticated
with check (public.is_hr_or_admin());
create policy profiles_update_hr on public.profiles
for update to authenticated
using (public.is_hr_or_admin())
with check (public.is_hr_or_admin());
create policy profiles_delete_admin on public.profiles
for delete to authenticated
using (public.current_user_role() = 'administrator');

-- Employees: HR/admin manage; employees see themselves; managers see their department;
-- payroll sees employee records needed for payroll administration.
create policy employees_read_scoped on public.employees
for select to authenticated
using (public.can_access_employee(id));
create policy employees_insert_hr on public.employees
for insert to authenticated
with check (public.is_hr_or_admin());
create policy employees_update_hr on public.employees
for update to authenticated
using (public.is_hr_or_admin())
with check (public.is_hr_or_admin());
create policy employees_delete_admin on public.employees
for delete to authenticated
using (public.current_user_role() = 'administrator');

-- Organization reference data.
create policy departments_read_authenticated on public.departments
for select to authenticated using (true);
create policy departments_manage_hr on public.departments
for all to authenticated
using (public.is_hr_or_admin()) with check (public.is_hr_or_admin());
create policy positions_read_authenticated on public.positions
for select to authenticated using (true);
create policy positions_manage_hr on public.positions
for all to authenticated
using (public.is_hr_or_admin()) with check (public.is_hr_or_admin());

-- Attendance: own records, HR/admin, or manager's department. Only HR/admin correct records.
create policy attendance_read_scoped on public.attendance_records
for select to authenticated
using (public.can_access_employee(employee_id));
create policy attendance_insert_self on public.attendance_records
for insert to authenticated
with check (employee_id = public.current_user_employee_id());
create policy attendance_update_hr on public.attendance_records
for update to authenticated
using (public.is_hr_or_admin()) with check (public.is_hr_or_admin());
create policy attendance_delete_admin on public.attendance_records
for delete to authenticated
using (public.current_user_role() = 'administrator');

-- Leave: applicants see/submit their own; HR/admin see all; managers see their department.
create policy leave_read_scoped on public.leave_applications
for select to authenticated
using (public.can_access_employee(employee_id));
create policy leave_insert_self on public.leave_applications
for insert to authenticated
with check (employee_id = public.current_user_employee_id());
create policy leave_update_hr on public.leave_applications
for update to authenticated
using (public.is_hr_or_admin()) with check (public.is_hr_or_admin());
create policy leave_update_manager_department on public.leave_applications
for update to authenticated
using (public.current_user_role() = 'manager' and public.can_access_employee(employee_id))
with check (public.current_user_role() = 'manager' and public.can_access_employee(employee_id));
create policy leave_delete_admin on public.leave_applications
for delete to authenticated
using (public.current_user_role() = 'administrator');

-- Leave types and balances.
create policy leave_types_read_authenticated on public.leave_types
for select to authenticated using (true);
create policy leave_types_manage_hr on public.leave_types
for all to authenticated using (public.is_hr_or_admin()) with check (public.is_hr_or_admin());
create policy leave_balances_read_scoped on public.leave_balances
for select to authenticated using (public.can_access_employee(employee_id));
create policy leave_balances_manage_hr on public.leave_balances
for all to authenticated using (public.is_hr_or_admin()) with check (public.is_hr_or_admin());

-- Training needs and programmes.
create policy training_needs_read_scoped on public.training_needs
for select to authenticated using (public.can_access_employee(employee_id));
create policy training_needs_insert_self on public.training_needs
for insert to authenticated with check (employee_id = public.current_user_employee_id());
create policy training_needs_manage_hr on public.training_needs
for all to authenticated using (public.is_hr_or_admin()) with check (public.is_hr_or_admin());
create policy training_needs_update_manager on public.training_needs
for update to authenticated
using (public.current_user_role() = 'manager' and public.can_access_employee(employee_id))
with check (public.current_user_role() = 'manager' and public.can_access_employee(employee_id));
create policy training_programmes_read_authenticated on public.training_programmes
for select to authenticated using (true);
create policy training_programmes_manage_hr on public.training_programmes
for all to authenticated using (public.is_hr_or_admin()) with check (public.is_hr_or_admin());
create policy training_participants_read_scoped on public.training_participants
for select to authenticated
using (public.is_hr_or_admin() or public.can_access_employee(employee_id));
create policy training_participants_manage_hr on public.training_participants
for all to authenticated using (public.is_hr_or_admin()) with check (public.is_hr_or_admin());
create policy training_evaluations_read_scoped on public.training_evaluations
for select to authenticated
using (
  public.is_hr_or_admin()
  or exists (
    select 1 from public.training_participants tp
    where tp.id = participant_id and public.can_access_employee(tp.employee_id)
  )
);
create policy training_evaluations_manage_hr on public.training_evaluations
for all to authenticated using (public.is_hr_or_admin()) with check (public.is_hr_or_admin());

-- Appraisals and scores: scores inherit access from their parent appraisal.
create policy appraisals_read_scoped on public.performance_appraisals
for select to authenticated
using (public.can_access_employee(employee_id) or manager_id = (select auth.uid()));
create policy appraisals_insert_hr on public.performance_appraisals
for insert to authenticated
with check (public.is_hr_or_admin());
create policy appraisals_insert_manager_department on public.performance_appraisals
for insert to authenticated
with check (
  public.current_user_role() = 'manager'
  and manager_id = (select auth.uid())
  and public.can_access_employee(employee_id)
);
create policy appraisals_update_hr on public.performance_appraisals
for update to authenticated
using (public.is_hr_or_admin()) with check (public.is_hr_or_admin());
create policy appraisals_update_assigned_manager on public.performance_appraisals
for update to authenticated
using (public.current_user_role() = 'manager' and manager_id = (select auth.uid()))
with check (public.current_user_role() = 'manager' and manager_id = (select auth.uid()) and public.can_access_employee(employee_id));
create policy appraisals_delete_admin on public.performance_appraisals
for delete to authenticated using (public.current_user_role() = 'administrator');
create policy appraisal_scores_read_parent_scope on public.appraisal_scores
for select to authenticated using (public.can_access_appraisal(appraisal_id));
create policy appraisal_scores_manage_hr on public.appraisal_scores
for all to authenticated
using (public.is_hr_or_admin()) with check (public.is_hr_or_admin());
create policy appraisal_scores_manage_manager on public.appraisal_scores
for all to authenticated
using (
  public.current_user_role() = 'manager'
  and exists (select 1 from public.performance_appraisals a
              where a.id = appraisal_id and a.manager_id = (select auth.uid()))
)
with check (
  public.current_user_role() = 'manager'
  and exists (select 1 from public.performance_appraisals a
              where a.id = appraisal_id and a.manager_id = (select auth.uid()))
);
create policy appraisal_periods_read_authenticated on public.appraisal_periods
for select to authenticated using (true);
create policy appraisal_periods_manage_hr on public.appraisal_periods
for all to authenticated using (public.is_hr_or_admin()) with check (public.is_hr_or_admin());
create policy appraisal_criteria_read_authenticated on public.appraisal_criteria
for select to authenticated using (true);
create policy appraisal_criteria_manage_hr on public.appraisal_criteria
for all to authenticated using (public.is_hr_or_admin()) with check (public.is_hr_or_admin());

-- Payroll: employees see their own payslip rows; HR/payroll/admin have operational access.
create policy payroll_records_read_scoped on public.payroll_records
for select to authenticated using (public.can_access_payroll_employee(employee_id));
create policy payroll_records_insert_payroll on public.payroll_records
for insert to authenticated
with check (public.current_user_role() in ('administrator','payroll'));
create policy payroll_records_update_payroll on public.payroll_records
for update to authenticated
using (public.current_user_role() in ('administrator','payroll'))
with check (public.current_user_role() in ('administrator','payroll'));
create policy payroll_records_delete_admin on public.payroll_records
for delete to authenticated using (public.current_user_role() = 'administrator');
create policy payroll_items_read_parent_scope on public.payroll_items
for select to authenticated
using (exists (
  select 1 from public.payroll_records pr
  where pr.id = payroll_record_id and public.can_access_payroll_employee(pr.employee_id)
));
create policy payroll_items_insert_payroll on public.payroll_items
for insert to authenticated
with check (public.current_user_role() in ('administrator','payroll'));
create policy payroll_items_update_payroll on public.payroll_items
for update to authenticated
using (public.current_user_role() in ('administrator','payroll'))
with check (public.current_user_role() in ('administrator','payroll'));
create policy payroll_items_delete_admin on public.payroll_items
for delete to authenticated using (public.current_user_role() = 'administrator');
create policy salary_structures_read_scoped on public.salary_structures
for select to authenticated using (public.can_access_payroll_employee(employee_id));
create policy salary_structures_insert_payroll on public.salary_structures
for insert to authenticated
with check (public.current_user_role() in ('administrator','payroll'));
create policy salary_structures_update_payroll on public.salary_structures
for update to authenticated
using (public.current_user_role() in ('administrator','payroll'))
with check (public.current_user_role() in ('administrator','payroll'));
create policy salary_structures_delete_admin on public.salary_structures
for delete to authenticated using (public.current_user_role() = 'administrator');
create policy payroll_periods_read_payroll_roles on public.payroll_periods
for select to authenticated
using (public.current_user_role() in ('administrator','hr','payroll'));
create policy payroll_periods_insert_payroll on public.payroll_periods
for insert to authenticated
with check (public.current_user_role() in ('administrator','payroll'));
create policy payroll_periods_update_payroll on public.payroll_periods
for update to authenticated
using (public.current_user_role() in ('administrator','payroll'))
with check (public.current_user_role() in ('administrator','payroll'));
create policy payroll_periods_delete_admin on public.payroll_periods
for delete to authenticated using (public.current_user_role() = 'administrator');

-- Shifts and holidays are readable by signed-in users; HR/admin maintain them.
create policy shifts_read_authenticated on public.shifts
for select to authenticated using (true);
create policy shifts_manage_hr on public.shifts
for all to authenticated using (public.is_hr_or_admin()) with check (public.is_hr_or_admin());
create policy holidays_read_authenticated on public.holidays
for select to authenticated using (true);
create policy holidays_manage_hr on public.holidays
for all to authenticated using (public.is_hr_or_admin()) with check (public.is_hr_or_admin());

-- Succession and recruitment contain sensitive workforce/candidate information.
create policy succession_read_hr_manager on public.succession_plans
for select to authenticated
using (public.current_user_role() in ('administrator','hr','manager'));
create policy succession_manage_hr on public.succession_plans
for all to authenticated
using (public.is_hr_or_admin()) with check (public.is_hr_or_admin());
create policy recruitment_read_hr on public.recruitment_applications
for select to authenticated using (public.is_hr_or_admin());
create policy recruitment_manage_hr on public.recruitment_applications
for all to authenticated using (public.is_hr_or_admin()) with check (public.is_hr_or_admin());

-- Notifications: only the recipient can read/update. Inserts are service-side/admin-only.
create policy notifications_read_own on public.notifications
for select to authenticated using (user_id = (select auth.uid()));
create policy notifications_update_own on public.notifications
for update to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));
create policy notifications_insert_hr on public.notifications
for insert to authenticated
with check (public.is_hr_or_admin());

-- Audit logs are append-only from trusted server-side code; ordinary clients cannot write.
create policy audit_logs_read_admin on public.audit_logs
for select to authenticated
using (public.current_user_role() = 'administrator');

-- System settings are restricted to HR/admin.
create policy system_settings_read_hr on public.system_settings
for select to authenticated using (public.is_hr_or_admin());
create policy system_settings_manage_hr on public.system_settings
for all to authenticated
using (public.is_hr_or_admin()) with check (public.is_hr_or_admin());

commit;

-- IMPORTANT: Review the Supabase SQL editor output. Then test each role using separate
-- authenticated sessions before importing real employee or payroll data.
