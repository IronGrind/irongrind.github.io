import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import vm from 'node:vm';
const code = await readFile(new URL('../../assets/js/auth.js', import.meta.url), 'utf8');
function setup(role, unavailable = false) {
    const elements = new Map();
    const element = id => {
        if (!elements.has(id)) elements.set(id, { value: '', disabled: false, checked: false, textContent: '', classList: { add() {}, remove() {} }, setAttribute(name, value) { this[name] = value; } });
        return elements.get(id);
    };
    const counters = { password: 0, endpoint: 0, session: 0, signOut: 0, logs: 0 };
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
        async rpc() { counters.logs++; return { error: null }; }
    };
    const storage = () => {
        const records = new Map();
        return { getItem: key => records.get(key) || null, setItem: (key, value) => records.set(key, value), removeItem: key => records.delete(key) };
    };
    let destination;
    const context = vm.createContext({ document: { getElementById: element, querySelector: () => element('submit') }, window: { ironGrindSupabase: client, location: { search: '', replace: url => destination = url } }, localStorage: storage(), sessionStorage: storage(), URLSearchParams, console });
    vm.runInContext(code, context);
    return { context, element, counters, destination: () => destination };
}
for (const [mode, role, target] of [['admin', 'admin', 'admin.html'], ['member', 'member', 'customer.html']]) {
    const test = setup(role);
    test.element('loginEmail').value = mode === 'admin' ? 'staff' : 'member@example.test';
    test.element('loginPassword').value = 'password';
    await vm.runInContext('handleLogin({preventDefault(){}})', test.context);
    assert.equal(test.destination(), target);
    assert.equal(test.counters.endpoint, mode === 'admin' ? 1 : 0);
    assert.equal(test.counters.password, mode === 'member' ? 1 : 0);
    assert.equal(test.counters.logs, mode === 'admin' ? 1 : 0);
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
console.log('Passed: admin endpoint/session flow, unchanged member email flow, activity attribution call, non-admin rejection, unavailable-function recovery.');
