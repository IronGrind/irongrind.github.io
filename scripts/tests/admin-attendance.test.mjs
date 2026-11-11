import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';
import test from 'node:test';
const source = readFileSync(new URL('../../assets/js/admin.js', import.meta.url), 'utf8');

function phoneStatusFixture(error, active = 'expired') {
    const stored = new Map();
    const context = vm.createContext({
        window: { ironGrindSupabase: { rpc: async () => ({ error }) } },
        mobileAttendanceSessionIds: new Set(['expired', 'other']),
        mobileAttendanceSessionPersistence: new Map([['expired', true], ['other', true]]),
        mobileAttendancePollBusy: new Set(['expired']),
        activeMobileAttendanceSessionId: active, activeMobileAttendancePairingUrl: 'old-qr',
        activeMobileAttendancePersistent: true, mobileAttendancePollTimer: 1,
        localStorage: { setItem: (key,value) => stored.set(key,value), removeItem: key => stored.delete(key) },
        clearInterval() {}, refreshPairedAttendancePhones() {},
        setAttendancePhoneStatus(message) { context.status = message; }, document: { getElementById: () => null }
    });
    vm.runInContext(source.slice(source.indexOf('function savePersistentMobileAttendanceSessions()'), source.indexOf('function setAttendancePhoneStatus(')), context);
    vm.runInContext(source.slice(source.indexOf('async function refreshAttendancePhoneStatus('), source.indexOf('async function restoreMobileAttendancePairing(')), context);
    return { context, stored };
}

test('expired pairing reference is removed without disturbing another selected phone', async () => {
    const { context, stored } = phoneStatusFixture({ message: 'Phone scanner session is inactive or expired' }, 'other');
    await context.refreshAttendancePhoneStatus('expired');
    assert.deepEqual([...context.mobileAttendanceSessionIds], ['other']);
    assert.equal(context.activeMobileAttendanceSessionId, 'other');
    assert.equal(context.mobileAttendanceSessionPersistence.has('expired'), false);
    assert.equal(stored.get('ig_mobile_attendance_session_ids'), '["other"]');
});

test('last expired reference stops polling and shows recovery without a migration instruction', async () => {
    const { context } = phoneStatusFixture({ message: 'Phone scanner session is inactive or expired' });
    context.mobileAttendanceSessionIds.delete('other');
    await context.refreshAttendancePhoneStatus('expired');
    assert.equal(context.activeMobileAttendanceSessionId, null);
    assert.equal(context.activeMobileAttendancePairingUrl, null);
    assert.equal(context.mobileAttendancePollTimer, null);
    assert.match(context.status, /expired or was ended/);
    assert.doesNotMatch(context.status, /migration/i);
});

test('transient status failures retain pairing references', async () => {
    const { context } = phoneStatusFixture({ message: 'Failed to fetch' });
    await context.refreshAttendancePhoneStatus('expired');
    assert.equal(context.mobileAttendanceSessionIds.size, 2);
    assert.equal(context.activeMobileAttendancePairingUrl, 'old-qr');
    assert.match(context.status, /saved pairings were kept/);
});
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
