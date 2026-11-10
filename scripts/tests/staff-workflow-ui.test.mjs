import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import test from 'node:test';
const source = fs.readFileSync('assets/js/staff.js', 'utf8');
function load(name, context) {
    const start = source.search(new RegExp(`(?:async )?function ${name}\\(`));
    const end = source.indexOf('\n}', start) + 2;
    vm.runInContext(source.slice(start, end), context);
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

test('attendance name lookup searches first and requires selection before recording', async () => {
    const elements = { staffIdentifier: { value: 'Ana' }, staffAttendanceResults: { replaceChildren() {}, append() {} } };
    let searched = false;
    const context = vm.createContext({ staffBusy: false, staffSelectedAttendanceMember: null, staffAttendanceSearchRevision: 0,
        document: { getElementById: id => elements[id] },
        staffClient: { rpc: async (name, args) => { assert.equal(name, 'staff_search_members'); assert.equal(args.p_query, 'Ana'); searched = true; return { data: [] }; } },
        recordStaffAttendance: () => { throw Error('Must select a member first'); }
    });
    load('submitStaffAttendanceLookup', context);
    await context.submitStaffAttendanceLookup({ preventDefault() {} });
    assert.ok(searched);
});

test('attendance records the selected member ID rather than their possibly shared name', async () => {
    let recorded;
    const context = vm.createContext({ staffBusy: false, staffSelectedAttendanceMember: { id: 'unique-member-id' }, pendingStaffScan: null,
        document: { getElementById: () => ({ value: 'Ana' }) },
        recordStaffAttendance: async id => { recorded = id; }, clearStaffAttendanceSelection() {}
    });
    load('submitStaffAttendanceLookup', context);
    await context.submitStaffAttendanceLookup({ preventDefault() {} });
    assert.equal(recorded, 'unique-member-id');
});
