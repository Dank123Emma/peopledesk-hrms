-- PeopleDesk HRMS Phase 6: training and performance workflows
begin;

alter table public.training_needs
  add column if not exists decision_reason text,
  add column if not exists approved_by uuid references auth.users(id),
  add column if not exists approved_at timestamptz;

alter table public.training_programmes
  add column if not exists category text,
  add column if not exists objectives text,
  add column if not exists provider text,
  add column if not exists capacity integer,
  add column if not exists created_by uuid references auth.users(id);

alter table public.training_participants
  add column if not exists registered_at timestamptz not null default now(),
  add column if not exists attended_at timestamptz,
  add column if not exists certificate_reference text;

alter table public.training_evaluations
  add column if not exists submitted_by uuid references auth.users(id);

alter table public.performance_appraisals
  add column if not exists self_assessment text,
  add column if not exists manager_feedback text,
  add column if not exists employee_acknowledged boolean not null default false,
  add column if not exists reviewed_at timestamptz;

-- Replace broad legacy policies with scoped policies.
drop policy if exists "hr manages training needs" on public.training_needs;
drop policy if exists "training read" on public.training_programmes;
drop policy if exists "hr manages programmes" on public.training_programmes;
drop policy if exists "participants read" on public.training_participants;
drop policy if exists "hr manages participants" on public.training_participants;
drop policy if exists "evaluations hr" on public.training_evaluations;
drop policy if exists "appraisals scoped" on public.performance_appraisals;
drop policy if exists "managers create appraisals" on public.performance_appraisals;
drop policy if exists "hr updates appraisals" on public.performance_appraisals;
drop policy if exists "appraisal scores scoped" on public.appraisal_scores;
drop policy if exists "managers manage scores" on public.appraisal_scores;
drop policy if exists training_needs_read_scoped on public.training_needs;
drop policy if exists training_needs_insert_self on public.training_needs;
drop policy if exists training_needs_manage_hr on public.training_needs;
drop policy if exists training_needs_update_manager on public.training_needs;
drop policy if exists training_programmes_read_authenticated on public.training_programmes;
drop policy if exists training_programmes_manage_hr on public.training_programmes;
drop policy if exists training_participants_read_scoped on public.training_participants;
drop policy if exists training_participants_manage_hr on public.training_participants;
drop policy if exists training_evaluations_read_scoped on public.training_evaluations;
drop policy if exists training_evaluations_manage_hr on public.training_evaluations;
drop policy if exists appraisals_read_scoped on public.performance_appraisals;
drop policy if exists appraisals_insert_manager_department on public.performance_appraisals;
drop policy if exists appraisals_update_hr on public.performance_appraisals;
drop policy if exists appraisals_update_assigned_manager on public.performance_appraisals;
drop policy if exists appraisals_delete_admin on public.performance_appraisals;
drop policy if exists appraisal_scores_read_parent_scope on public.appraisal_scores;
drop policy if exists appraisal_scores_manage_hr on public.appraisal_scores;
drop policy if exists appraisal_scores_manage_manager on public.appraisal_scores;
drop policy if exists appraisal_periods_read_authenticated on public.appraisal_periods;
drop policy if exists appraisal_periods_manage_hr on public.appraisal_periods;
drop policy if exists appraisal_criteria_read_authenticated on public.appraisal_criteria;
drop policy if exists appraisal_criteria_manage_hr on public.appraisal_criteria;
drop policy if exists "training needs read scoped" on public.training_needs;
drop policy if exists "employees submit training needs" on public.training_needs;
drop policy if exists "hr decides training needs" on public.training_needs;
drop policy if exists "training programmes visible to authenticated" on public.training_programmes;
drop policy if exists "hr manages training programmes" on public.training_programmes;
drop policy if exists "training participants scoped read" on public.training_participants;
drop policy if exists "hr manages training participants" on public.training_participants;
drop policy if exists "training evaluations scoped read" on public.training_evaluations;
drop policy if exists "participant submits evaluation" on public.training_evaluations;
drop policy if exists "hr manages training evaluations" on public.training_evaluations;
drop policy if exists "appraisals read scoped" on public.performance_appraisals;
drop policy if exists "hr or assigned manager creates appraisals" on public.performance_appraisals;
drop policy if exists "hr or assigned manager updates appraisal" on public.performance_appraisals;
drop policy if exists "appraisal scores read scoped" on public.appraisal_scores;
drop policy if exists "hr and assigned managers manage scores" on public.appraisal_scores;
drop policy if exists "appraisal periods visible authenticated" on public.appraisal_periods;
drop policy if exists "hr manages appraisal periods" on public.appraisal_periods;
drop policy if exists "appraisal criteria visible authenticated" on public.appraisal_criteria;
drop policy if exists "hr manages appraisal criteria" on public.appraisal_criteria;

create policy "training needs read scoped" on public.training_needs for select to authenticated
using (public.is_hr_or_admin()
  or employee_id=(select employee_id from public.profiles where id=auth.uid())
  or (public.current_user_role()='manager' and employee_id in (select id from public.employees where department=(select department from public.profiles where id=auth.uid()))));
create policy "employees submit training needs" on public.training_needs for insert to authenticated
with check (public.is_hr_or_admin() or employee_id=(select employee_id from public.profiles where id=auth.uid()));
create policy "hr decides training needs" on public.training_needs for update to authenticated
using (public.is_hr_or_admin() or (public.current_user_role()='manager' and employee_id in (select id from public.employees where department=(select department from public.profiles where id=auth.uid()))))
with check (public.is_hr_or_admin() or (public.current_user_role()='manager' and employee_id in (select id from public.employees where department=(select department from public.profiles where id=auth.uid()))));

create policy "training programmes visible to authenticated" on public.training_programmes for select to authenticated using (true);
create policy "hr manages training programmes" on public.training_programmes for all to authenticated
using (public.is_hr_or_admin()) with check (public.is_hr_or_admin());

create policy "training participants scoped read" on public.training_participants for select to authenticated
using (public.is_hr_or_admin() or employee_id=(select employee_id from public.profiles where id=auth.uid()));
create policy "hr manages training participants" on public.training_participants for all to authenticated
using (public.is_hr_or_admin()) with check (public.is_hr_or_admin());

create policy "training evaluations scoped read" on public.training_evaluations for select to authenticated
using (public.is_hr_or_admin() or participant_id in (select id from public.training_participants where employee_id=(select employee_id from public.profiles where id=auth.uid())));
create policy "participant submits evaluation" on public.training_evaluations for insert to authenticated
with check (public.is_hr_or_admin() or participant_id in (select id from public.training_participants where employee_id=(select employee_id from public.profiles where id=auth.uid()) and attendance_status='Attended'));
create policy "hr manages training evaluations" on public.training_evaluations for update to authenticated
using (public.is_hr_or_admin()) with check (public.is_hr_or_admin());

create policy "appraisals read scoped" on public.performance_appraisals for select to authenticated
using (public.is_hr_or_admin() or employee_id=(select employee_id from public.profiles where id=auth.uid()) or manager_id=auth.uid());
create policy "hr or assigned manager creates appraisals" on public.performance_appraisals for insert to authenticated
with check (public.is_hr_or_admin() or (public.current_user_role()='manager' and manager_id=auth.uid() and public.can_access_employee(employee_id)));
create policy "hr or assigned manager updates appraisal" on public.performance_appraisals for update to authenticated
using (status <> 'Finalized' and (public.is_hr_or_admin() or manager_id=auth.uid()))
with check (status <> 'Finalized' and (public.is_hr_or_admin() or manager_id=auth.uid()));

create or replace function public.submit_appraisal_self_assessment(p_appraisal_id uuid, p_assessment text)
returns void language plpgsql security definer set search_path=public
as $$
begin
  if not exists (
    select 1 from public.performance_appraisals a
    join public.profiles p on p.employee_id=a.employee_id
    where a.id=p_appraisal_id and p.id=auth.uid() and p.is_active=true
      and a.status <> 'Finalized'
  ) then raise exception 'Appraisal not found or not available for self-assessment'; end if;
  update public.performance_appraisals
  set self_assessment=p_assessment, status='Self Assessment'
  where id=p_appraisal_id;
end;
$$;
revoke all on function public.submit_appraisal_self_assessment(uuid,text) from public;
grant execute on function public.submit_appraisal_self_assessment(uuid,text) to authenticated;


create policy "appraisal scores read scoped" on public.appraisal_scores for select to authenticated
using (public.is_hr_or_admin() or appraisal_id in (select id from public.performance_appraisals where employee_id=(select employee_id from public.profiles where id=auth.uid()) or manager_id=auth.uid()));
create policy "hr and assigned managers manage scores" on public.appraisal_scores for all to authenticated
using (public.is_hr_or_admin() and appraisal_id in (select id from public.performance_appraisals where status <> 'Finalized')
  or appraisal_id in (select id from public.performance_appraisals where manager_id=auth.uid() and status <> 'Finalized'))
with check (public.is_hr_or_admin() and appraisal_id in (select id from public.performance_appraisals where status <> 'Finalized')
  or appraisal_id in (select id from public.performance_appraisals where manager_id=auth.uid() and status <> 'Finalized'));

create policy "appraisal periods visible authenticated" on public.appraisal_periods for select to authenticated using (true);
create policy "hr manages appraisal periods" on public.appraisal_periods for all to authenticated
using (public.is_hr_or_admin()) with check (public.is_hr_or_admin());
create policy "appraisal criteria visible authenticated" on public.appraisal_criteria for select to authenticated using (true);
create policy "hr manages appraisal criteria" on public.appraisal_criteria for all to authenticated
using (public.is_hr_or_admin()) with check (public.is_hr_or_admin());

create or replace function public.enrol_training_participant(p_programme_id uuid, p_employee_id uuid)
returns uuid language plpgsql security definer set search_path=public
as $$
declare v_participant_id uuid; v_capacity integer; v_count integer;
begin
  if not public.is_hr_or_admin() then raise exception 'Only HR may enrol training participants'; end if;
  select capacity into v_capacity from public.training_programmes where id=p_programme_id and status in ('Planned','In Progress');
  if not found then raise exception 'Training programme is unavailable for enrolment'; end if;
  if exists(select 1 from public.training_participants where programme_id=p_programme_id and employee_id=p_employee_id) then
    raise exception 'Employee is already enrolled in this programme';
  end if;
  select count(*) into v_count from public.training_participants where programme_id=p_programme_id;
  if v_capacity is not null and v_count >= v_capacity then raise exception 'Programme capacity has been reached'; end if;
  insert into public.training_participants(programme_id,employee_id,attendance_status,completion_status)
  values(p_programme_id,p_employee_id,'Registered','Pending') returning id into v_participant_id;
  return v_participant_id;
end;
$$;
revoke all on function public.enrol_training_participant(uuid,uuid) from public;
grant execute on function public.enrol_training_participant(uuid,uuid) to authenticated;
revoke insert on public.training_participants from authenticated;

create or replace function public.finalize_appraisal(p_appraisal_id uuid)
returns void language plpgsql security definer set search_path=public
as $$
begin
  if not (public.is_hr_or_admin() or exists (
    select 1 from public.performance_appraisals a
    where a.id=p_appraisal_id and a.manager_id=auth.uid()
      and public.current_user_role()='manager'
  )) then raise exception 'Not authorized to finalize this appraisal'; end if;
  if not exists (select 1 from public.appraisal_scores where appraisal_id=p_appraisal_id) then
    raise exception 'Appraisal must have scores before finalization';
  end if;
  if exists (
    select 1 from public.appraisal_criteria c
    where c.active=true and not exists (
      select 1 from public.appraisal_scores s where s.appraisal_id=p_appraisal_id and s.criterion_id=c.id
    )
  ) then raise exception 'All active appraisal criteria must be scored'; end if;
  update public.performance_appraisals a
  set overall_score=(select round(sum(s.score*c.weight)/nullif(sum(c.weight),0),2)
       from public.appraisal_scores s join public.appraisal_criteria c on c.id=s.criterion_id
       where s.appraisal_id=a.id and c.active=true),
      status='Finalized', finalized_at=now(), reviewed_at=coalesce(reviewed_at,now())
  where a.id=p_appraisal_id and a.status <> 'Finalized';
  if not found then raise exception 'Appraisal is already finalized or unavailable'; end if;
end;
$$;
revoke all on function public.finalize_appraisal(uuid) from public;
grant execute on function public.finalize_appraisal(uuid) to authenticated;

create or replace function public.acknowledge_appraisal(p_appraisal_id uuid)
returns void language plpgsql security definer set search_path=public
as $$
begin
  update public.performance_appraisals a
  set employee_acknowledged=true
  where a.id=p_appraisal_id and a.status='Finalized'
    and a.employee_id=(select employee_id from public.profiles where id=auth.uid() and is_active=true);
  if not found then raise exception 'Appraisal not found or not available for acknowledgement'; end if;
end;
$$;
revoke all on function public.acknowledge_appraisal(uuid) from public;
grant execute on function public.acknowledge_appraisal(uuid) to authenticated;

commit;
