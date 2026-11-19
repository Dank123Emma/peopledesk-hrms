import { calculateWeightedAppraisalScore } from "../js/performance-calculator.js";
const criteria = [{id:"a",weight:60},{id:"b",weight:40}];
const scores = [{criterion_id:"a",score:5},{criterion_id:"b",score:3}];
const result = calculateWeightedAppraisalScore(scores,criteria);
if (result !== 4.2) throw new Error(`Expected 4.2, got ${result}`);
for (const bad of [0,6,NaN]) {
  let failed=false;
  try { calculateWeightedAppraisalScore([{criterion_id:"a",score:bad},{criterion_id:"b",score:3}],criteria); }
  catch { failed=true; }
  if(!failed) throw new Error(`Expected invalid score ${bad} to fail`);
}
let failed=false;
try { calculateWeightedAppraisalScore(scores,[{id:"a",weight:0},{id:"b",weight:40}]); }
catch { failed=true; }
if(!failed) throw new Error("Expected zero weight to fail");
console.log("PeopleDesk performance calculator tests passed.");
