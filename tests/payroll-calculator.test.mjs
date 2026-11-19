import assert from 'node:assert/strict';
import { calculatePayroll, calculatePaye } from '../js/payroll-calculator.js';

const result = calculatePayroll({ basic: 3000, period: '2026-11' });
assert.equal(result.gross, 3000);
assert.equal(result.employeeSsnit, 165);
assert.equal(result.employerPension, 390);
assert.equal(result.taxableIncome, 2835);
assert.equal(result.paye, 375.73);
assert.equal(result.net, 2459.27);
assert.equal(result.employerCost, 3390);
assert.equal(calculatePaye(588, '2026-11'), 0);
assert.equal(calculatePaye(668, '2026-11'), 4);
assert.equal(calculatePaye(768, '2026-11'), 14);
assert.throws(() => calculatePaye(1000, '2026-08'), /No PAYE band/);
assert.throws(() => calculatePayroll({ basic: -1, period: '2026-11' }), /negative/);
assert.throws(() => calculatePayroll({ basic: 100, otherDeductions: 200, period: '2026-11' }), /exceed gross/);
console.log('PeopleDesk payroll calculator tests passed.');
