-- PeopleDesk HRMS Phase 3: keep employee directory changes aligned with linked profiles.
-- Apply after the base schema and Phase 1 RLS hardening migration.
-- This does not delete or recreate employee or account records.

begin;

create or replace function public.sync_employee_profile()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
set row_security = off
as $$
begin
  update public.profiles
     set full_name = new.full_name,
         department = new.department,
         is_active = case
           when new.employment_status in ('Inactive', 'Terminated') then false
           else is_active
         end
   where employee_id = new.id;
  return new;
end;
$$;

revoke all on function public.sync_employee_profile() from public, anon, authenticated;

drop trigger if exists employees_sync_profile on public.employees;
create trigger employees_sync_profile
after update of full_name, department, employment_status on public.employees
for each row execute function public.sync_employee_profile();

commit;
