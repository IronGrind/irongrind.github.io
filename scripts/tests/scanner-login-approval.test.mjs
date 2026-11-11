import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import test from 'node:test';
function fixture(rpc) {
    const intervals = new Map(), appended = [];
    let next = 0;
    function element() {
        const children = new Map();
        const buttons = [{ dataset: { decision: 'deny' } }, { dataset: { decision: 'approve' } }];
        return { dataset: {}, setAttribute() {}, addEventListener() {}, showModal() { this.modalOpened = true; }, close() {}, remove() { this.removed = true; },
            querySelector(selector) { if (!children.has(selector)) children.set(selector, { textContent: '' }); return children.get(selector); },
            querySelectorAll() { return buttons; } };
    }
    const window = { addEventListener() {}, removeEventListener() {} };
    const status = { textContent: '' };
    const document = { hidden: false, getElementById: () => status, createElement: element, body: { append: item => appended.push(item) }, addEventListener() {}, removeEventListener() {} };
    vm.runInNewContext(fs.readFileSync('assets/js/scanner-login-approval.js', 'utf8'), {
        window, document, navigator: { userAgent: 'Test phone', onLine: true },
        setInterval: fn => { intervals.set(++next, fn); return next; }, clearInterval: id => intervals.delete(id), Date
    });
    return { window, client: { rpc }, appended, status, tick: async () => { for (const fn of [...intervals.values()]) await fn(); }, intervals };
}
test('first scanner needs no handoff approval or dialog', async () => {
    const f = fixture(async () => ({ data: { status: 'ready' } }));
    await f.window.waitForScannerLoginApproval(f.client);
    assert.equal(f.appended.length, 0);
});
test('incoming scanner waits for approval and disposes its dialog and timer', async () => {
    let count = 0;
    const f = fixture(async () => ({ data: { status: ++count === 1 ? 'pending' : 'approved', expires_at: '2099-01-01' } }));
    const waiting = f.window.waitForScannerLoginApproval(f.client);
    await new Promise(setImmediate);
    assert.equal(f.appended.length, 1);
    await f.tick(); await waiting;
    assert.equal(f.appended[0].removed, true);
    assert.equal(f.intervals.size, 0);
});
test('denial rejects the incoming scanner without activating a session', async () => {
    const calls = [];
    const f = fixture(async name => { calls.push(name); return { data: { status: 'denied' } }; });
    await assert.rejects(f.window.waitForScannerLoginApproval(f.client), /denied/);
    assert.deepEqual(calls, ['request_scanner_login_approval']);
});
test('current scanner displays requester as text and submits an explicit approval', async () => {
    const calls = [];
    const f = fixture(async (name, args) => {
        calls.push([name, args]);
        return name === 'list_scanner_login_approvals' ? { data: [{ id: 'request', device_label: '<untrusted label>' }] } : {};
    });
    f.window.startScannerApprovalNotifications(f.client);
    await new Promise(setImmediate);
    const panel = f.appended[0];
    assert.equal(panel.modalOpened, true);
    assert.equal(panel.querySelector('.approval-device').textContent, '<untrusted label>');
    await panel.querySelectorAll()[1].onclick();
    assert.equal(calls[1][0], 'decide_scanner_login_approval');
    assert.equal(calls[1][1].p_approve, true);
    assert.equal(panel.removed, true);
    f.window.stopScannerApprovalNotifications(f.client);
    assert.equal(f.intervals.size, 0);
});
test('failed decision leaves the current scanner notification available to retry', async () => {
    const f = fixture(async name => name === 'list_scanner_login_approvals'
        ? { data: [{ id: 'request', device_label: 'Phone' }] } : { error: { message: 'Offline' } });
    f.window.startScannerApprovalNotifications(f.client);
    await new Promise(setImmediate);
    const panel = f.appended[0];
    await panel.querySelectorAll()[0].onclick();
    assert.equal(panel.removed, undefined);
    assert.match(panel.querySelector('.approval-result').textContent, /stays signed in/);
    assert.ok(panel.querySelectorAll().every(button => !button.disabled));
    f.window.stopScannerApprovalNotifications(f.client);
});

test('polling failure is visible and manual retry opens the approval dialog', async () => {
    let fail = true;
    const f = fixture(async () => fail ? { error: { code: 'PGRST202' } }
        : { data: [{ id: 'request', device_label: 'Phone' }] });
    f.window.startScannerApprovalNotifications(f.client);
    await new Promise(setImmediate);
    assert.match(f.status.textContent, /failed \(PGRST202\)/);
    assert.equal(f.appended.length, 0);
    fail = false;
    f.client.__refreshScannerApprovals();
    await new Promise(setImmediate);
    assert.equal(f.appended[0].modalOpened, true);
    f.window.stopScannerApprovalNotifications(f.client);
    assert.equal(f.client.__refreshScannerApprovals, null);
});

test('recovery requires a server-confirmed inactive scanner and is explicitly requested', async () => {
    let active = true, recoveries = 0;
    const f = fixture(async name => {
        if (name === 'request_scanner_login_approval') return { data: { status: 'pending', expires_at: '2099-01-01' } };
        if (name === 'recover_inactive_attendance_session') {
            recoveries++;
            return active ? { error: { message: 'SCANNER_STILL_ACTIVE' } } : {};
        }
        throw Error('Unexpected call');
    });
    const waiting = f.window.waitForScannerLoginApproval(f.client);
    await new Promise(setImmediate);
    assert.equal(recoveries, 0);
    const dialog = f.appended[0];
    await dialog.querySelector('[data-action="recover"]').onclick();
    assert.equal(dialog.removed, undefined);
    assert.match(dialog.querySelector('[role="status"]').textContent, /active within the last two minutes/);
    active = false;
    await dialog.querySelector('[data-action="recover"]').onclick();
    await waiting;
    assert.equal(recoveries, 2);
    assert.equal(dialog.removed, true);
});
