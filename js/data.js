// Demo data is for local evaluation only. Production data is loaded from Supabase.
const now = new Date();
const day = n => new Date(now.getFullYear(), now.getMonth(), now.getDate()-n).toISOString().slice(0,10);
export const demo = {
  employees: [
    {id:"EMP-0001",full_name:"Esther Mensah",gender:"Female",email:"esther.mensah@example.com",phone:"024 000 1001",department:"Operations",position:"Teller",employment_date:"2022-04-11",status:"Active",salary:3200},
    {id:"EMP-0002",full_name:"Abigail Asante",gender:"Female",email:"abigail.asante@example.com",phone:"024 000 1002",department:"Customer Service",position:"Customer Service Officer",employment_date:"2021-08-02",status:"Active",salary:3800},
    {id:"EMP-0003",full_name:"John Mensh",gender:"Male",email:"john.mensh@example.com",phone:"024 000 1003",department:"Finance",position:"Accounts Officer",employment_date:"2020-02-17",status:"Active",salary:3000},
    {id:"EMP-0004",full_name:"Kofi Mush",gender:"Male",email:"kofi.mush@example.com",phone:"024 000 1004",department:"Finance",position:"Senior Accountant",employment_date:"2018-06-04",status:"Active",salary:5200},
    {id:"EMP-0005",full_name:"Akua Owusu",gender:"Female",email:"akua.owusu@example.com",phone:"024 000 1005",department:"Human Resources",position:"HR Officer",employment_date:"2023-01-09",status:"Active",salary:4100}
  ],
  attendance: [
    {id:"AT-01",employee_name:"Esther Mensah",employee_id:"EMP-0001",work_date:day(0),clock_in:"08:04",clock_out:"17:02",status:"Present",hours:8.97},
    {id:"AT-02",employee_name:"Abigail Asante",employee_id:"EMP-0002",work_date:day(0),clock_in:"08:17",clock_out:"17:00",status:"Late",hours:8.72},
    {id:"AT-03",employee_name:"John Mensh",employee_id:"EMP-0003",work_date:day(0),clock_in:"07:56",clock_out:"17:10",status:"Present",hours:9.23},
    {id:"AT-04",employee_name:"Kofi Mush",employee_id:"EMP-0004",work_date:day(0),clock_in:"—",clock_out:"—",status:"Absent",hours:0}
  ],
  leave: [{id:"LV-001",employee_name:"Abigail Asante",employee_id:"EMP-0002",leave_type:"Maternity",start_date:day(-8),end_date:day(-90),days:90,status:"Approved",reason:"Maternity leave"}],
  leaveTypes: [{id:"LT-1",name:"Annual"},{id:"LT-2",name:"Sick"},{id:"LT-3",name:"Maternity"},{id:"LT-4",name:"Casual"}],
  leaveBalances: [],
  shifts: [{id:"SH-1",name:"Standard office",start_time:"08:00:00",end_time:"17:00:00",grace_period_minutes:10,active:true}],
  holidays: [],
  shiftAssignments: [],
  training: [{id:"TR-001",employee_name:"Esther Mensah",employee_id:"EMP-0001",title:"Teller Operations Training",category:"Technical",start_date:day(-2),end_date:day(5),status:"Pending",reason:"Strengthen teller operations competence"}],
  trainingProgrammes: [{id:"TP-001",title:"Customer Service Excellence",category:"Soft Skills",provider:"Internal HR",trainer:"Training Team",venue:"Main Office",start_date:day(7),end_date:day(8),budget:1200,status:"Planned",objectives:"Improve customer communication and service recovery",capacity:20}],
  trainingParticipants: [{id:"TPT-001",programme_id:"TP-001",employee_id:"EMP-0002",employee_name:"Abigail Asante",attendance_status:"Registered",completion_status:"Pending"}],
  trainingEvaluations: [],
  appraisalPeriods: [{id:"AP-001",name:"2026 Annual Review",start_date:"2026-01-01",end_date:"2026-12-31",status:"Open"}],
  appraisalCriteria: [{id:"AC-001",name:"Punctuality & attendance",weight:15,active:true},{id:"AC-002",name:"Communication",weight:15,active:true},{id:"AC-003",name:"Teamwork",weight:15,active:true},{id:"AC-004",name:"Productivity & quality",weight:25,active:true},{id:"AC-005",name:"Customer service",weight:15,active:true},{id:"AC-006",name:"Objectives & targets",weight:15,active:true}],
  appraisals: [],
  appraisalScores: [],
  payroll: [{id:"PR-001",employee_name:"John Mensh",employee_id:"EMP-0003",period:now.toISOString().slice(0,7),basic:3000,allowances:500,earnings:3500,deductions:400,net:3100,status:"Draft"}],
  payrollComponents: [],
  succession: [{id:"SC-001",position:"Chief Accountant",incumbent:"Current Chief Accountant",successor:"Kofi Mush",training_status:"Completed",readiness:"Ready",vacancy:"No vacancy expected",department:"Finance",risk_level:"Medium",development_plan:"Completed leadership training"}],
  successionActions: [],
  vacancies: [{id:"VAC-001",title:"HR Officer",department:"Human Resources",position:"HR Officer",job_description:"Support HR operations and employee services.",requirements:"Relevant experience",employment_type:"Permanent",location:"Accra",opening_date:day(0),closing_date:day(30),status:"Open"}],
  interviews: [],
  recruitment: Array.from({length:5},(_,i)=>({id:`APP-00${i+1}`,applicant_name:["Nana Boateng","Esi Arthur","Yaw Addo","Mavis Osei","Kojo Frimpong"][i],position:"General Application",application_date:day(i),status:["Received","Under Review","Received","Shortlisted","Received"][i]}))
};
