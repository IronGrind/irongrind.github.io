import assert from 'node:assert/strict';
import test from 'node:test';
import { addDateOnlyDays, isValidDateOnly, manilaBusinessDate, validateStaffMembershipTerms } from '../../supabase/functions/admin-create-member/validation.js';

const beforeManilaMidnight = new Date('2026-11-10T15:30:00.000Z');
const afterManilaMidnight = new Date('2026-11-10T16:30:00.000Z');

test('staff plan duration and price are validated using the Philippine business date', () => {
    assert.equal(manilaBusinessDate(beforeManilaMidnight), '2026-11-10');
    assert.equal(manilaBusinessDate(afterManilaMidnight), '2026-11-11');
    for (const [plan, price, days] of [['Monthly', 800, 30], ['Half Month', 400, 15], ['Walk-in', 80, 1]]) {
        const startDate = '2026-11-10';
        const expiryDate = addDateOnlyDays(startDate, days);
        assert.equal(validateStaffMembershipTerms({ plan, price, startDate, expiryDate, now: beforeManilaMidnight }), true);
    }
});

test('staff registration rejects mismatched price, arbitrary term, stale or future dates, and unknown plans', () => {
    const valid = { plan: 'Monthly', price: 800, startDate: '2026-11-10', expiryDate: '2026-12-10', now: beforeManilaMidnight };
    assert.equal(validateStaffMembershipTerms({ ...valid, price: 400 }), false);
    assert.equal(validateStaffMembershipTerms({ ...valid, expiryDate: '2026-12-09' }), false);
    assert.equal(validateStaffMembershipTerms({ ...valid, startDate: '2026-11-09', expiryDate: '2026-12-09' }), false);
    assert.equal(validateStaffMembershipTerms({ ...valid, startDate: '2026-11-11', expiryDate: '2026-12-11' }), false);
    assert.equal(validateStaffMembershipTerms({ ...valid, plan: 'Lifetime' }), false);
});

test('date-only parsing rejects impossible or noncanonical dates', () => {
    assert.equal(isValidDateOnly('2028-02-29'), true);
    assert.equal(isValidDateOnly('2027-02-29'), false);
    assert.equal(isValidDateOnly('2026-2-03'), false);
    assert.equal(isValidDateOnly('2026-04-31'), false);
});
