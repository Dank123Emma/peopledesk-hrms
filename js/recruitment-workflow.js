export const candidateStages = ["Received", "Under Review", "Shortlisted", "Interviewed", "Selected", "Rejected"];
const progression = {"Received":"Under Review", "Under Review":"Shortlisted", "Shortlisted":"Interviewed", "Interviewed":"Selected"};
export function nextCandidateStage(current) { return progression[current] || null; }
export function isCandidateTransitionAllowed(current, next) {
  return next === "Rejected" ? !["Selected", "Rejected"].includes(current) : progression[current] === next;
}
export const vacancyStages = ["Draft", "Pending Approval", "Open", "Closed", "Cancelled"];
export function isVacancyTransitionAllowed(current, next, isAdministrator=false) {
  if (current === "Draft" && next === "Pending Approval") return true;
  if (current === "Pending Approval" && next === "Open") return Boolean(isAdministrator);
  if (current === "Open" && next === "Closed") return true;
  return false;
}
