// Demo/preview calculator only. Production payroll is calculated in PostgreSQL RPCs.
const RESIDENT_BANDS_2026_09 = [
  {width:588,rate:0},{width:80,rate:0.05},{width:100,rate:0.10},
  {width:2900,rate:0.175},{width:16000,rate:0.25},{width:30332,rate:0.30},{width:null,rate:0.35}
];
export function calculatePaye(chargeableIncome, period, resident=true){
  const income=Math.max(0,Number(chargeableIncome)||0);
  if(!resident)return round(income*0.25);
  if(String(period).slice(0,7)<"2026-09")throw new Error("No PAYE band schedule configured for this period in the demo calculator.");
  let remaining=income,tax=0;
  for(const band of RESIDENT_BANDS_2026_09){
    const portion=band.width===null?remaining:Math.min(remaining,band.width);
    tax+=portion*band.rate;remaining-=portion;
    if(remaining<=0)break;
  }
  return round(tax);
}
export function calculatePayroll({basic,allowances=0,taxableAllowances=allowances,otherDeductions=0,taxRelief=0,period,resident=true,ssnitMin=587.80,ssnitMax=69000,employeeSsnitRate=0.055,employerPensionRate=0.13}){
  basic=Number(basic)||0;allowances=Number(allowances)||0;taxableAllowances=Number(taxableAllowances)||0;otherDeductions=Number(otherDeductions)||0;taxRelief=Number(taxRelief)||0;
  if([basic,allowances,taxableAllowances,otherDeductions,taxRelief].some(v=>v<0))throw new Error("Payroll amounts cannot be negative.");
  const gross=basic+allowances;
  const insurable=Math.min(ssnitMax,Math.max(ssnitMin,basic));
  const employeeSsnit=round(insurable*employeeSsnitRate);
  const employerPension=round(insurable*employerPensionRate);
  const taxableIncome=Math.max(0,basic+taxableAllowances-employeeSsnit-taxRelief);
  const paye=calculatePaye(taxableIncome,period,resident);
  const deductions=employeeSsnit+paye+otherDeductions;
  if(deductions>gross)throw new Error("Payroll deductions exceed gross earnings.");
  return {basic,allowances,gross,insurable,employeeSsnit,employerPension,taxableIncome,paye,otherDeductions,taxRelief, deductions,net:round(gross-deductions),employerCost:round(gross+employerPension)};
}
function round(v){return Math.round((v+Number.EPSILON)*100)/100}
