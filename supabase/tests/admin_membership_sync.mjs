import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import vm from 'node:vm';
const source = await readFile(new URL('../../assets/js/admin.js', import.meta.url), 'utf8');
const start = source.indexOf('async function loadSupabaseMembershipData()');
const end = source.indexOf('async function loadSupabaseOperationalData(', start);
assert.ok(start >= 0 && end > start);
let remoteMembers = [{ id: 'remote', auth_user_id: null, full_name: 'Saved record' }];
let fail = false;
const saved = new Map();
const context = vm.createContext({
    window: { ironGrindSupabase: { from(table) {
        const result = () => ({ data: table === 'members' ? remoteMembers : [], error: fail ? { message: 'Offline' } : null });
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
remoteMembers = [];
await vm.runInContext('loadSupabaseMembershipData()', context);
assert.equal(context.members.length, 0, 'Deleted unlinked rows must not return from cache');
context.members = [{ id: 'cached' }];
fail = true;
await vm.runInContext('loadSupabaseMembershipData()', context);
assert.equal(context.members[0].id, 'cached', 'Read failures must preserve the last view');
context.window.ironGrindSupabase = null;
fail = false;
await vm.runInContext('loadSupabaseMembershipData()', context);
assert.equal(context.members[0].id, 'cached', 'Offline mode retains local records');
console.log('Passed: connected mode mirrors database rows, deleted rows do not reappear, read failures/offline mode preserve the existing view.');
