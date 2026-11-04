import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';
import test from 'node:test';
const source = readFileSync(new URL('../../assets/js/admin.js', import.meta.url), 'utf8');
test('admin scans use the atomic RPC and reuse uncertain request identifiers', async () => {
    const calls = [];
    const context = vm.createContext({ crypto: globalThis.crypto, Map,
        window: { ironGrindSupabase: { rpc: async (name, args) => {
            calls.push({ name, args });
            return calls.length === 1 ? { error: { message: 'Connection lost' } }
                : { data: { action: 'check_in', member_name: 'Member' } };
        } } }, toast() {}, loadSupabaseOperationalData: async () => {}, renderAttendance() {}, renderDashboard() {}
    });
    const start = source.indexOf('const pendingAdminAttendanceScans');
    const end = source.indexOf('async function checkOut(', start);
    assert.ok(start >= 0 && end > start);
    vm.runInContext(source.slice(start, end), context);
    await context.recordMemberAttendanceScan({ id: 'member' });
    await context.recordMemberAttendanceScan({ id: 'member' });
    assert.equal(calls[0].name, 'record_attendance_scan');
    assert.equal(calls[0].args.p_request_id, calls[1].args.p_request_id);
    await context.recordMemberAttendanceScan({ id: 'member' });
    assert.notEqual(calls[1].args.p_request_id, calls[2].args.p_request_id);
});
