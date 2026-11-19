/** Calculate a weighted appraisal score on a 1–5 scale.
 * Criteria weights are normalized to their sum, so weights need not total 100.
 */
export function calculateWeightedAppraisalScore(scores, criteria) {
  if (!Array.isArray(scores) || !Array.isArray(criteria) || scores.length === 0) {
    throw new Error("At least one appraisal score and criterion are required.");
  }
  const byCriterion = new Map(scores.map(item => [String(item.criterion_id), Number(item.score)]));
  const active = criteria.filter(item => item.active !== false);
  if (!active.length) throw new Error("At least one active criterion is required.");
  let weightedTotal = 0;
  let weightTotal = 0;
  for (const criterion of active) {
    const weight = Number(criterion.weight);
    const score = byCriterion.get(String(criterion.id));
    if (!Number.isFinite(weight) || weight <= 0) throw new Error("Criterion weights must be positive numbers.");
    if (!Number.isFinite(score) || score < 1 || score > 5) throw new Error("Each criterion score must be between 1 and 5.");
    weightedTotal += score * weight;
    weightTotal += weight;
  }
  return Number((weightedTotal / weightTotal).toFixed(2));
}
