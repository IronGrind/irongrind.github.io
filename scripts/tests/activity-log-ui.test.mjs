import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import test from 'node:test';
function setup(rows) {
    const elements = new Map(), calls = [];
    const element = id => {
        if (!elements.has(id)) elements.set(id, { value: '', disabled: false, innerHTML: '', textContent: '', append() {}, addEventListener() {}, setAttribute() {}, removeAttribute() {} });
        return elements.get(id);
    };
    element('activityFilters').querySelectorAll = () => [];
    const query = {};
    for (const method of ['select','order','eq','in','ilike','gte','lt']) query[method] = (...args) => { calls.push([method, ...args]); return query; };
    query.range = async () => ({ data: rows, count: rows.length });
    const context = vm.createContext({ Intl, Date, console, document: { getElementById: element, createElement: () => ({}) },
        window: { ironGrindSupabase: { from: () => query } } });
    vm.runInContext(fs.readFileSync('assets/js/activity-logs.js','utf8'),context);
    return { element, calls, load: context.window.loadActivityLogs };
}
const event = { id: 1, occurred_at: '2026-11-10T00:00:00Z', actor_name: 'Operator', actor_role: 'staff', actor_id: 'technical-account-id', entity_id: 'technical-record-id', entity_type: 'security', record_label: 'Example', action: 'member_sign_in_failed', details: 'Shared generic description', changed_fields: [] };
test('action remains distinct from descriptions and technical IDs stay inside details', async () => {
    const fixture = setup([event]); await fixture.load();
    const html = fixture.element('activityTable').innerHTML;
    assert.match(html, /Member sign-in failed/);
    const beforeDetails = html.slice(0, html.indexOf('<details'));
    assert.doesNotMatch(beforeDetails, /technical-account-id|technical-record-id|Shared generic description/);
    assert.match(html, /<summary>Details<\/summary>/);
    assert.match(html, /Nov 10, 2026, 8:00/);
});
test('category and action filters are applied together on the server', async () => {
    const fixture = setup([]);
    fixture.element('activityArea').value='membership';
    fixture.element('activityAction').value='renewal';
    await fixture.load();
    const category = fixture.calls.find(call => call[0] === 'in');
    assert.equal(category[1], 'entity_type');
    assert.deepEqual(Array.from(category[2]), ['members','membership_applications','membership_history']);
    assert.ok(fixture.calls.some(call => call[0] === 'eq' && call[1] === 'action' && call[2] === 'renewal'));
});
test('stock updates do not imply stock was added and rendered data is escaped', async () => {
    const fixture=setup([{ ...event, entity_type:'products', action:'update', changed_fields:['stock'], details:'<script>alert(1)</script>', actor_name:'<img onerror=bad>' }]);
    await fixture.load(); const html=fixture.element('activityTable').innerHTML;
    assert.match(html,/Product stock updated/);
    assert.doesNotMatch(html,/<script>|<img onerror/);
    assert.match(html,/&lt;script&gt;/);
});
