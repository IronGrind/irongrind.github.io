import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import test from 'node:test';
const source = fs.readFileSync('assets/js/supabase-client.js', 'utf8');
const start = source.indexOf('window.stopAccountSessionMonitor');
const end = source.indexOf('\nif (/(?:^|', start);
const settle = () => new Promise(resolve => setImmediate(resolve));
function setup() {
    let tick, session = { access_token: 'token' }, listener;
    let unsubscribed = false, cleared = false;
    const reasons = [];
    const client = { rpc: async () => ({ data: true }), auth: {
        getSession: async () => ({ data: { session } }),
        onAuthStateChange: callback => { listener = callback; return { data: { subscription: { unsubscribe() { unsubscribed = true; } } } }; }
    } };
    const context = vm.createContext({ window: { addEventListener() {}, removeEventListener() {} },
        document: { addEventListener() {}, removeEventListener() {} }, navigator: {}, console,
        setInterval: fn => { tick = fn; return 1; }, clearInterval: () => { cleared = true; }, setTimeout: fn => fn()
    });
    vm.runInContext(source.slice(start, end), context);
    context.window.monitorAccountSession(client, reason => { reasons.push(reason); });
    return { client, reasons, context, tick: () => tick(), notify: () => listener(), clearSession: () => { session = null; }, cleaned: () => unsubscribed && cleared };
}
test('intentional logout stops checks and suppresses expiry redirects', async () => {
    const fixture = setup(); await settle();
    fixture.context.window.stopAccountSessionMonitor(fixture.client);
    fixture.clearSession(); fixture.notify(); await fixture.tick(); await settle();
    assert.deepEqual(fixture.reasons, []); assert.ok(fixture.cleaned());
});
test('unexpected session loss still reports expiry', async () => {
    const fixture = setup(); await settle(); fixture.clearSession(); await fixture.tick();
    assert.deepEqual(fixture.reasons, ['expired']);
});
test('logout cancels an already-running session check', async () => {
    const fixture = setup(); await settle();
    let complete;
    fixture.client.auth.getSession = () => new Promise(resolve => { complete = resolve; });
    const pending = fixture.tick();
    fixture.context.window.stopAccountSessionMonitor(fixture.client);
    complete({ data: { session: null } }); await pending;
    assert.deepEqual(fixture.reasons, []);
});
