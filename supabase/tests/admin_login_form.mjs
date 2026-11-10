import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import vm from 'node:vm';
const code = await readFile(new URL('../../assets/js/auth.js', import.meta.url), 'utf8');
function setup(role, unavailable = false, activationFails = false) {
    const elements = new Map();
    const element = id => {
        if (!elements.has(id)) elements.set(id, { value: '', disabled: false, checked: false, textContent: '', addEventListener() {}, classList: { add() {}, remove() {} }, setAttribute(name, value) { this[name] = value; } });
        return elements.get(id);
    };
    const counters = { password: 0, endpoint: 0, session: 0, signOut: 0, logs: 0, activation: 0 };
    const authResult = { data: { user: { id: 'account-id', email: 'account@example.test' } }, error: null };
    const client = {
        auth: {
            async signInWithPassword() { counters.password++; return authResult; },
            async setSession() { counters.session++; return authResult; },
            async signOut() { counters.signOut++; }
        },
        functions: { async invoke() { counters.endpoint++; return unavailable ? { data: null, error: {} } : { data: { session: { access_token: 'test', refresh_token: 'test' } }, error: null }; } },
        from(table) {
            const query = {
                select() { return query; }, eq() { return query; },
                async single() { return { data: { role, username: 'staff', full_name: 'Name' }, error: null }; },
                async maybeSingle() { return { data: table === 'members' ? { id: 'member-id' } : null, error: null }; }
            }; return query;
        },
        async rpc(name) { if (name === 'activate_account_session') counters.activation++; else counters.logs++; return { error: name === 'activate_account_session' && activationFails ? { message: 'Session activation failed' } : null }; }
    };
    const storage = () => {
        const records = new Map();
        return { getItem: key => records.get(key) || null, setItem: (key, value) => records.set(key, value), removeItem: key => records.delete(key) };
    };
    let destination;
    const context = vm.createContext({ document: { getElementById: element, querySelector: () => element('submit') }, window: { ironGrindSupabase: client, requireMemberDeviceApproval: async () => {}, requireAdminMfa: async () => {}, location: { search: '', replace: url => destination = url } }, localStorage: storage(), sessionStorage: storage(), URLSearchParams, console });
    vm.runInContext(code, context);
    return { context, element, counters, destination: () => destination };
}
for (const [mode, role, target] of [['admin', 'admin', 'admin.html'], ['admin', 'staff', 'staff.html'], ['member', 'member', 'customer.html']]) {
    const test = setup(role);
    test.element('loginEmail').value = mode === 'admin' ? 'staff' : 'member@example.test';
    test.element('loginPassword').value = 'password';
    await vm.runInContext('handleLogin({preventDefault(){}})', test.context);
    assert.equal(test.destination(), target);
    assert.equal(test.counters.endpoint, 1);
    assert.equal(test.counters.password, 0);
    assert.equal(test.counters.logs, 1);
    assert.equal(test.counters.activation, 1, 'Every successful login secures its session');
    assert.equal(test.element('submit').disabled, false);
}
for (const [role, unavailable] of [['member', false], ['admin', true]]) {
    const test = setup(role, unavailable);
    test.element('loginEmail').value = 'staff';
    test.element('loginPassword').value = 'password';
    await vm.runInContext('handleLogin({preventDefault(){}})', test.context);
    assert.equal(test.destination(), undefined);
    assert.equal(test.element('submit').disabled, false);
    assert.ok(test.element('loginErrorText').textContent);
}
console.log('Passed: username/member audited endpoint flows, session activation, activity calls, role rejection, and unavailable-function recovery.');
const failedActivation=setup('admin',false,true);
failedActivation.element('loginEmail').value='admin'; failedActivation.element('loginPassword').value='password';
await vm.runInContext('handleLogin({preventDefault(){}})',failedActivation.context);
assert.equal(failedActivation.destination(),undefined);
assert.equal(failedActivation.counters.signOut,1,'Failed activation cannot open a dashboard');
const cancelledMfa=setup('admin');
cancelledMfa.element('loginEmail').value='admin';cancelledMfa.element('loginPassword').value='password';
cancelledMfa.context.window.requireAdminMfa=async()=>{throw new Error('Sign-in cancelled.');};
await vm.runInContext('handleLogin({preventDefault(){}})',cancelledMfa.context);
assert.equal(cancelledMfa.counters.activation,0,'MFA must finish before replacing an application session');
assert.equal(cancelledMfa.destination(),undefined);
assert.equal(cancelledMfa.counters.signOut,1,'Cancelled new login is signed out');
console.log('Passed: cancelled MFA does not activate or replace the existing application session.');
