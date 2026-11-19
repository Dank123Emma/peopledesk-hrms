# Phase 5 — Payroll management

## Scope
- Effective-dated statutory settings and resident PAYE bands.
- Recurring employee earning and deduction components.
- Monthly payroll generation for active employees.
- Employee SSNIT deduction, employer pension contribution, PAYE, approved reliefs, net pay and employer cost.
- Draft → Approved → Paid period workflow.
- Payroll component and calculation summaries in the frontend.

## Migration
Apply `database/migrations/20261119_phase5_payroll.sql` after the base schema, Phase 1 RLS, and Phase 3/4 migrations. Back up the database first. The migration is additive and does not delete existing records.

The seeded 2026 statutory configuration uses the SSNIT official 2026 insurable earnings limits and contribution rates; the seeded resident monthly PAYE bands are from GRA and effective 1 September 2026. Rates are effective-dated so administrators/payroll can add future schedules. Validate all configuration with GRA, SSNIT and the organization's payroll adviser before production.

## Usage
1. Ensure active employees have correct basic salary or effective-dated `salary_structures`.
2. Insert recurring allowances/deductions into `employee_payroll_components` with effective dates. Set `taxable` for taxable earnings. Set `tax_relief` only for deductions whose tax relief eligibility has been confirmed.
3. In Payroll, choose a month and **Generate payroll**. The protected RPC creates draft records and itemized lines. It refuses to regenerate a period with existing payroll records.
4. Review records and statutory values, then use **Approve period**. Only Draft periods can be approved.
5. After payment is confirmed externally, use **Mark paid**. This records Paid status; it does not initiate a bank transfer.

## Statutory assumptions / limitations
- Resident PAYE bands effective 1 September 2026 are seeded. Historical bands before that date are not included; generating an earlier period fails until an effective schedule is configured.
- Non-resident PAYE is currently a flat 25% in the calculation function. The payroll generation RPC currently calculates employees as resident; employee tax residency is not yet modeled per employee.
- SSNIT employee rate is 5.5% and employer contribution is 13% of configured insurable earnings. 2026 minimum and maximum insurable earnings are seeded as GH₵587.80 and GH₵69,000.00. Verify employee-category exceptions and applicable limits.
- Approved tax-relief deductions can be configured on components, but the organization must verify eligibility and documentation.
- Bonus/overtime-specific tax rules, tax relief profiles, employee non-resident status, annual reconciliation, GRA upload formats, Tier 2 trustee remittance files, bank payment integrations, PDF payslips and audit event triggers are not included in this phase.
- Employer pension is shown as additional employer cost and is not deducted from employee net pay.
- Payroll generation, approval and paid status use database RPCs. Payment itself is an external process.

## Testing
- `js/payroll-calculator.js` is a demo-only calculator; production generation uses PostgreSQL functions.
- Test employee, payroll and administrator roles against RLS in a separate Supabase project before production use.
- Confirm employee payslip access is scoped to their own records and payroll components.

## Official reference links
- GRA PAYE rates: https://gra.gov.gh/domestic-tax/tax-types/paye/
- GRA 2026 amendment notice: https://gra.gov.gh/news/portfolio/amendments-income-tax-act-2026-act-1178/
- SSNIT 2026 insurable earnings notice: https://www.ssnit.org.gh/wp-content/uploads/2026/01/Public-Notice-Min-Max-Insurable.pdf
- SSNIT contribution FAQ: https://www.ssnit.org.gh/faqs/
