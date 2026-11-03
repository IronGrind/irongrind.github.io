import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import vm from 'node:vm';
const source = await readFile(new URL('../../assets/js/admin.js', import.meta.url), 'utf8');
const start = source.indexOf('async function loadSupabaseMembershipData()');
const end = source.indexOf('async function loadSupabaseOperationalData(', start);
assert.ok(start >= 0 && end > start);
let remoteMembers = [{ id: 'remote', auth_user_id: null, full_name: 'Saved record' }];
let remoteApplications = [];
let fail = false;
const saved = new Map();
const context = vm.createContext({
    window: { ironGrindSupabase: { from(table) {
        const result = () => ({ data: table === 'members' ? remoteMembers : remoteApplications, error: fail ? { message: 'Offline' } : null });
        return { select() { return { ...result(), eq: result }; } };
    } } },
    members: [{ id: 'stale', authUserId: null }],
    pendingApprovals: [{ id: 'stale-application' }],
    mapSupabaseMember: row => ({ id: row.id, authUserId: row.auth_user_id }),
    saveDB: (key, value) => saved.set(key, value),
    renderDashboard() {}, renderMembers() {}, renderApprovals() {}, toast() {},
    console: { error() {} }
});
vm.runInContext(source.slice(start, end), context);
await vm.runInContext('loadSupabaseMembershipData()', context);
assert.deepEqual(Array.from(context.members, row => row.id), ['remote']);
assert.equal(context.pendingApprovals.length, 0);
remoteApplications = [{ id: 'new-registration', application_type: 'registration', status: 'pending', full_name: 'New applicant' }];
await vm.runInContext('loadSupabaseMembershipData()', context);
assert.equal(context.pendingApprovals.length, 1);
assert.equal(context.pendingApprovals[0].id, 'new-registration');
assert.equal(context.pendingApprovals[0].source, 'supabase-registration');
remoteApplications = [];
remoteMembers = [];
await vm.runInContext('loadSupabaseMembershipData()', context);
assert.equal(context.members.length, 0, 'Deleted unlinked rows must not return from cache');
assert.equal(context.pendingApprovals.length, 0, 'Processed or deleted applications must leave the pending list');
context.members = [{ id: 'cached' }];
fail = true;
await vm.runInContext('loadSupabaseMembershipData()', context);
assert.equal(context.members[0].id, 'cached', 'Read failures must preserve the last view');
context.window.ironGrindSupabase = null;
fail = false;
await vm.runInContext('loadSupabaseMembershipData()', context);
assert.equal(context.members[0].id, 'cached', 'Offline mode retains local records');
const markup = await readFile(new URL('../../admin.html', import.meta.url), 'utf8');
const elements = new Map();
context.document = { getElementById(id) {
    assert.ok(markup.includes(`id="${id}"`), `Dashboard element ${id} must exist`);
    if (!elements.has(id)) elements.set(id, { textContent: '', innerHTML: '', classList: { toggle(name, value) { this[name] = value; } } });
    return elements.get(id);
} };
Object.assign(context, { members: [], attendance: [], sales: [], products: [], todayStr: () => '2026-11-04', formatPeso: amount => `PHP ${amount}` });
const renderStart = source.indexOf('function renderDashboard()');
const renderEnd = source.indexOf('/* ========== RENDER: MEMBERS', renderStart);
vm.runInContext(source.slice(renderStart, renderEnd), context);
context.pendingApprovals = [
    { id: 'new-registration', status: 'pending', source: 'supabase-registration' },
    { id: 'renewal', status: 'pending', source: 'dashboard-renewal' }
];
context.renderDashboard();
assert.equal(elements.get('dashboardRegistrationNotice').classList.hidden, false);
assert.equal(elements.get('dashboardRegistrationNoticeText').textContent, '1 application is waiting for approval.');
assert.equal(elements.get('pendingBadge').textContent, 2);
assert.equal(elements.get('registrationApprovalsCount').textContent, 1);
context.pendingApprovals.shift();
context.renderDashboard();
assert.equal(elements.get('dashboardRegistrationNotice').classList.hidden, true, 'Only registration requests show the registration notice');
console.log('Passed: new registrations show the admin dashboard notice and badge, deleted rows do not reappear, read failures/offline mode preserve the existing view.');
