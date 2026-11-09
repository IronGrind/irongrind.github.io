import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import test from 'node:test';
const source = fs.readFileSync('assets/js/staff.js', 'utf8');
function load(name, context) {
    const start = source.search(new RegExp(`(?:async )?function ${name}\\(`));
    const next = source.slice(start + 1).search(/\n(?:async )?function /);
    vm.runInContext(source.slice(start, start + 1 + next), context);
}
test('supplement groups use saved form and conservative legacy unit fallback', () => {
    const context = vm.createContext({}); load('staffSupplementForm', context);
    for (const form of ['powder', 'capsule', 'tablet', 'drinkable', 'other']) {
        assert.equal(context.staffSupplementForm({ supplement_form: form }), form);
    }
    assert.equal(context.staffSupplementForm({ unit: 'gram' }), 'powder');
    assert.equal(context.staffSupplementForm({ unit: 'milliliter' }), 'drinkable');
    assert.equal(context.staffSupplementForm({ unit: 'piece' }), 'other');
});
test('request search and type filters combine without changing request records', () => {
    const cards = [
        { dataset: { searchText: 'ana monthly', requestType: 'renewal' } },
        { dataset: { searchText: 'juan monthly', requestType: 'registration' } }
    ];
    const elements = { staffRequestSearch: { value: 'ANA' }, staffRequestType: { value: 'renewal' }, staffRequestsStatus: {} };
    const context = vm.createContext({ document: { getElementById: id => elements[id], querySelectorAll: () => cards } });
    load('filterStaffRequests', context); context.filterStaffRequests();
    assert.equal(cards[0].hidden, false); assert.equal(cards[1].hidden, true);
    elements.staffRequestType.value = 'registration'; context.filterStaffRequests();
    assert.ok(cards.every(card => card.hidden));
    assert.match(elements.staffRequestsStatus.textContent, /No matching/);
});
test('cancelling membership confirmation prevents a payment write', async () => {
    let prompt;
    const context = vm.createContext({
        staffSelectedRenewalMember: { full_name: 'Ana', plan: 'Monthly', expiry_date: '2026-11-11' },
        document: { getElementById: id => id === 'staffRenewalPlan' ? { value: 'Monthly|800|30' } : {} },
        staffMembershipDates: () => ({ startDate: '2026-11-10', expiryDate: '2026-12-10' }),
        formatStaffPeso: value => `PHP ${value}`,
        window: { confirm: value => { prompt = value; return false; } },
        staffClient: { rpc: () => { throw new Error('Must not write'); } }
    });
    load('submitStaffMembershipChange', context);
    await context.submitStaffMembershipChange('renewal');
    assert.match(prompt, /Ana/); assert.match(prompt, /PHP 800/); assert.match(prompt, /2026-12-10/);
});
