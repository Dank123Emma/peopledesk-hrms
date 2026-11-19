-- Optional demo seed. Run only in a dedicated test Supabase project.
insert into public.departments(name) values ('Operations'),('Customer Service'),('Finance'),('Human Resources') on conflict do nothing;
insert into public.employees(employee_id,full_name,gender,email,phone,department,position,employment_date,basic_salary)
values
('EMP-0001','Esther Mensah','Female','esther.mensah@example.com','024 000 1001','Operations','Teller','2022-04-11',3200),
('EMP-0002','Abigail Asante','Female','abigail.asante@example.com','024 000 1002','Customer Service','Customer Service Officer','2021-08-02',3800),
('EMP-0003','John Mensh','Male','john.mensh@example.com','024 000 1003','Finance','Accounts Officer','2020-02-17',3000),
('EMP-0004','Kofi Mush','Male','kofi.mush@example.com','024 000 1004','Finance','Senior Accountant','2018-06-04',5200)
on conflict(employee_id) do nothing;
insert into public.succession_plans(position,incumbent,successor,training_status,readiness,vacancy)
values('Chief Accountant','Current Chief Accountant','Kofi Mush','Completed','Ready','No vacancy expected');
insert into public.recruitment_applications(applicant_name,position,status)
values ('Nana Boateng','General Application','Received'),('Esi Arthur','General Application','Under Review'),
('Yaw Addo','General Application','Received'),('Mavis Osei','General Application','Shortlisted'),
('Kojo Frimpong','General Application','Received');
