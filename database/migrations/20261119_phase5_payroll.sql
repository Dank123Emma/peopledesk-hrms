begin;

-- PeopleDesk HRMS Phase 5: configurable Ghana payroll calculations and workflow.
-- Rates are versioned by effective date. Confirm payroll policy with GRA/SSNIT before production.

create table if not exists public.payroll_statutory_config (
  id uuid primary key default gen_random_uuid(),
  effective_from date not null unique,
  employee_ssnit_rate numeric(7,5) not null default 0.055,
  employer_pension_rate numeric(7,5) not null default 0.13,
  minimum_insurable_earnings numeric(12,2) not null default 587.80,
  maximum_insurable_earnings numeric(12,2) not null default 69000.00,
  currency text not null default 'GHS',
  notes text,
  created_at timestamptz not null default now(),
  check(employee_ssnit_rate between 0 and 1),
  check(employer_pension_rate between 0 and 1),
  check(minimum_insurable_earnings >= 0 and maximum_insurable_earnings >= minimum_insurable_earnings)
);

create table if not exists public.payroll_tax_bands (
  id uuid primary key default gen_random_uuid(),
  effective_from date not null,
  lower_bound numeric(12,2) not null,
  upper_bound numeric(12,2),
  rate numeric(7,5) not null,
  resident_only boolean not null default true,
  source_note text,
  check(lower_bound >= 0),
  check(upper_bound is null or upper_bound > lower_bound),
  check(rate between 0 and 1),
  unique(effective_from, lower_bound, resident_only)
);

create table if not exists public.employee_payroll_components (
  id uuid primary key default gen_random_uuid(),
  employee_id uuid not null references public.employees(id) on delete cascade,
  component_type text not null check(component_type in ('Earning','Deduction')),
  name text not null,
  amount numeric(12,2) not null check(amount >= 0),
  taxable boolean not null default true,
  tax_relief boolean not null default false,
  effective_from date not null,
  effective_to date,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  check(effective_to is null or effective_to >= effective_from)
);
alter table public.employee_payroll_components add column if not exists tax_relief boolean not null default false;

alter table public.payroll_records
  add column if not exists employee_ssnit numeric(12,2) not null default 0,
  add column if not exists employer_pension numeric(12,2) not null default 0,
  add column if not exists paye numeric(12,2) not null default 0,
  add column if not exists taxable_income numeric(12,2) not null default 0,
  add column if not exists employer_cost numeric(12,2) not null default 0,
  add column if not exists generated_at timestamptz,
  add column if not exists approved_at timestamptz,
  add column if not exists paid_at timestamptz;

alter table public.payroll_periods
  add column if not exists generated_at timestamptz,
  add column if not exists notes text;

insert into public.payroll_statutory_config(effective_from,employee_ssnit_rate,employer_pension_rate,minimum_insurable_earnings,maximum_insurable_earnings,notes)
values ('2026-01-01',0.055,0.13,587.80,69000.00,'2026 SSNIT minimum/maximum insurable earnings; verify applicability for employee category.')
on conflict(effective_from) do nothing;

-- Resident monthly PAYE bands effective 1 September 2026, as published by GRA.
insert into public.payroll_tax_bands(effective_from,lower_bound,upper_bound,rate,source_note) values
('2026-09-01',0,588,0.00,'GRA PAYE monthly resident bands effective 2026-09-01'),
('2026-09-01',588,668,0.05,'GRA PAYE monthly resident bands effective 2026-09-01'),
('2026-09-01',668,768,0.10,'GRA PAYE monthly resident bands effective 2026-09-01'),
('2026-09-01',768,3668,0.175,'GRA PAYE monthly resident bands effective 2026-09-01'),
('2026-09-01',3668,19668,0.25,'GRA PAYE monthly resident bands effective 2026-09-01'),
('2026-09-01',19668,50000,0.30,'GRA PAYE monthly resident bands effective 2026-09-01'),
('2026-09-01',50000,null,0.35,'GRA PAYE monthly resident bands effective 2026-09-01')
on conflict(effective_from,lower_bound,resident_only) do nothing;

create or replace function public.payroll_paye(p_chargeable_income numeric,p_period date,p_resident boolean default true)
returns numeric
language plpgsql stable security definer
set search_path=public,pg_temp
as $$
declare band record; tax numeric:=0; slice numeric;
begin
  if p_chargeable_income <= 0 then return 0; end if;
  if not p_resident then return round(p_chargeable_income*0.25,2); end if;
  for band in
    select lower_bound,upper_bound,rate from public.payroll_tax_bands
    where resident_only=true and effective_from = (select max(effective_from) from public.payroll_tax_bands where resident_only=true and effective_from<=p_period)
    order by lower_bound
  loop
    slice:=greatest(0,least(p_chargeable_income,coalesce(band.upper_bound,p_chargeable_income))-band.lower_bound);
    tax:=tax+slice*band.rate;
  end loop;
  if not exists(select 1 from public.payroll_tax_bands where resident_only=true and effective_from<=p_period) then
    raise exception 'No PAYE bands configured for payroll period %',p_period;
  end if;
  return round(tax,2);
end $$;

create or replace function public.generate_payroll_period(p_period date)
returns jsonb
language plpgsql security definer
set search_path=public,pg_temp
as $$
declare
  v_period date:=date_trunc('month',p_period)::date;
  v_run public.payroll_periods%rowtype;
  e record; s numeric; gross numeric; taxable_gross numeric; other_deductions numeric; tax_relief_amount numeric;
  insurable numeric; insurable_min numeric; insurable_max numeric; ssnit_rate numeric; employer_rate numeric; emp_ssnit numeric; employer_pension numeric; taxable numeric; tax numeric; net numeric;
  rec_id uuid; comp record; count_records integer:=0;
begin
  if coalesce(public.current_user_role(),'') not in ('administrator','payroll') then raise exception 'Not authorized to generate payroll'; end if;
  insert into public.payroll_periods(period_month,status) values(v_period,'Draft')
    on conflict(period_month) do nothing;
  select * into v_run from public.payroll_periods where period_month=v_period for update;
  if v_run.status not in ('Draft','Processing') then raise exception 'Payroll period is locked (status: %)',v_run.status; end if;
  if exists(select 1 from public.payroll_records where payroll_period=v_period) then
    raise exception 'Payroll records already exist for %. Delete draft records before regenerating.',v_period;
  end if;
  update public.payroll_periods set status='Processing',generated_at=now() where id=v_run.id;
  for e in select * from public.employees where employment_status='Active' order by employee_id loop
    select ss.basic_salary into s from public.salary_structures ss
      where ss.employee_id=e.id and ss.effective_from<=v_period and (ss.effective_to is null or ss.effective_to>=v_period)
      order by ss.effective_from desc limit 1;
    s:=coalesce(s,e.basic_salary,0);
    gross:=s; taxable_gross:=s; other_deductions:=0; tax_relief_amount:=0;
    for comp in select * from public.employee_payroll_components
      where employee_id=e.id and effective_from<=v_period and (effective_to is null or effective_to>=v_period)
    loop
      if comp.component_type='Earning' then gross:=gross+comp.amount; if comp.taxable then taxable_gross:=taxable_gross+comp.amount; end if;
      else other_deductions:=other_deductions+comp.amount; if comp.tax_relief then tax_relief_amount:=tax_relief_amount+comp.amount; end if; end if;
    end loop;
    select minimum_insurable_earnings,maximum_insurable_earnings,employee_ssnit_rate,employer_pension_rate
      into insurable_min,insurable_max,ssnit_rate,employer_rate from public.payroll_statutory_config
      where effective_from<=v_period order by effective_from desc limit 1;
    if insurable_min is null then raise exception 'No statutory payroll configuration for %',v_period; end if;
    insurable:=least(insurable_max,greatest(insurable_min,s));
    emp_ssnit:=round(insurable*ssnit_rate,2);
    employer_pension:=round(insurable*employer_rate,2);
    taxable:=greatest(0,taxable_gross-emp_ssnit-tax_relief_amount);
    tax:=public.payroll_paye(taxable,v_period,true);
    net:=gross-emp_ssnit-tax-other_deductions;
    if net<0 then raise exception 'Net pay cannot be negative for employee %',e.employee_id; end if;
    insert into public.payroll_records(employee_id,payroll_period,basic_salary,total_earnings,total_deductions,status,employee_ssnit,employer_pension,paye,taxable_income,employer_cost,generated_at)
    values(e.id,v_period,s,gross,emp_ssnit+tax+other_deductions,'Draft',emp_ssnit,employer_pension,tax,taxable,gross+employer_pension,now()) returning id into rec_id;
    insert into public.payroll_items(payroll_record_id,item_type,description,amount) values
      (rec_id,'Earning','Basic salary',s),
      (rec_id,'Deduction','Employee SSNIT contribution',emp_ssnit),
      (rec_id,'Deduction','PAYE',tax);
    for comp in select * from public.employee_payroll_components where employee_id=e.id and effective_from<=v_period and (effective_to is null or effective_to>=v_period) loop
      insert into public.payroll_items(payroll_record_id,item_type,description,amount) values(rec_id,comp.component_type,comp.name,comp.amount);
    end loop;
    count_records:=count_records+1;
  end loop;
  update public.payroll_periods set status='Draft',generated_at=now() where id=v_run.id;
  return jsonb_build_object('period',v_period,'records_generated',count_records,'status','Draft');
end $$;

create or replace function public.approve_payroll_period(p_period date)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare v_period date:=date_trunc('month',p_period)::date; v_count int;
begin
  if coalesce(public.current_user_role(),'') not in ('administrator','payroll') then raise exception 'Not authorized to approve payroll'; end if;
  update public.payroll_periods set status='Approved',approved_by=auth.uid(),approved_at=now()
    where period_month=v_period and status='Draft';
  if not found then raise exception 'Payroll period is missing or not in Draft status'; end if;
  update public.payroll_records set status='Approved',approved_at=now() where payroll_period=v_period and status='Draft';
  get diagnostics v_count=row_count;
  return jsonb_build_object('period',v_period,'records_approved',v_count,'status','Approved');
end $$;

create or replace function public.mark_payroll_paid(p_period date)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare v_period date:=date_trunc('month',p_period)::date; v_count int;
begin
  if coalesce(public.current_user_role(),'') not in ('administrator','payroll') then raise exception 'Not authorized to mark payroll paid'; end if;
  update public.payroll_periods set status='Paid',paid_at=now() where period_month=v_period and status='Approved';
  if not found then raise exception 'Payroll period must be approved before marking paid'; end if;
  update public.payroll_records set status='Paid',paid_at=now() where payroll_period=v_period and status='Approved';
  get diagnostics v_count=row_count;
  return jsonb_build_object('period',v_period,'records_paid',v_count,'status','Paid');
end $$;

-- Restrict direct table changes; privileged operations should use the RPCs above.
alter table public.payroll_statutory_config enable row level security;
alter table public.payroll_tax_bands enable row level security;
alter table public.employee_payroll_components enable row level security;

drop policy if exists payroll_statutory_read_roles on public.payroll_statutory_config;
create policy payroll_statutory_read_roles on public.payroll_statutory_config for select to authenticated
using (public.current_user_role() in ('administrator','hr','payroll'));
drop policy if exists payroll_statutory_manage_admin on public.payroll_statutory_config;
create policy payroll_statutory_manage_admin on public.payroll_statutory_config for all to authenticated
using (public.current_user_role() in ('administrator','payroll')) with check (public.current_user_role() in ('administrator','payroll'));

drop policy if exists payroll_tax_bands_read_roles on public.payroll_tax_bands;
create policy payroll_tax_bands_read_roles on public.payroll_tax_bands for select to authenticated
using (public.current_user_role() in ('administrator','hr','payroll'));
drop policy if exists payroll_tax_bands_manage_admin on public.payroll_tax_bands;
create policy payroll_tax_bands_manage_admin on public.payroll_tax_bands for all to authenticated
using (public.current_user_role() in ('administrator','payroll')) with check (public.current_user_role() in ('administrator','payroll'));

drop policy if exists employee_payroll_components_read_scoped on public.employee_payroll_components;
create policy employee_payroll_components_read_scoped on public.employee_payroll_components for select to authenticated
using (public.can_access_payroll_employee(employee_id));
drop policy if exists employee_payroll_components_manage_payroll on public.employee_payroll_components;
create policy employee_payroll_components_manage_payroll on public.employee_payroll_components for all to authenticated
using (public.current_user_role() in ('administrator','payroll')) with check (public.current_user_role() in ('administrator','payroll'));

revoke all on function public.payroll_paye(numeric,date,boolean) from public,anon;
revoke all on function public.generate_payroll_period(date) from public,anon;
revoke all on function public.approve_payroll_period(date) from public,anon;
revoke all on function public.mark_payroll_paid(date) from public,anon;
grant execute on function public.payroll_paye(numeric,date,boolean) to authenticated;
grant execute on function public.generate_payroll_period(date) to authenticated;
grant execute on function public.approve_payroll_period(date) to authenticated;
grant execute on function public.mark_payroll_paid(date) to authenticated;

commit;
