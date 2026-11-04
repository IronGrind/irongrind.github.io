import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';
import test from 'node:test';
function storage() {
    const values = new Map([['irongrind_session', '{"role":"admin"}']]);
    return { getItem: key => values.get(key) ?? null, removeItem: key => values.delete(key) };
}
const localStorage = storage();
const sessionStorage = storage();
let redirectedTo = '';
const context = vm.createContext({
    localStorage, sessionStorage,
    window: { location: { replace(value) { redirectedTo = value; } } }
});
vm.runInContext(readFileSync(new URL('../../assets/js/admin-access.js', import.meta.url), 'utf8'), context);
function client(role, profileError = null) {
    return {
        auth: { getUser: async () => ({ data: { user: role ? { id: 'verified-user' } : null } }) },
        from: () => ({ select: () => ({ eq: () => ({ maybeSingle: async () => ({ data: { role, username: 'account' }, error: profileError }) }) }) })
    };
}
test('pairing requires a verified admin login independently of UI storage', async () => {
    const check = context.window.requireVerifiedAdmin;
    await assert.rejects(check(client(null)), /login has expired/);
    await assert.rejects(check(client('staff')), /current account has staff access/);
    await assert.rejects(check(client('member')), /current account has member access/);
    await assert.rejects(check(client('admin', { message: 'Network unavailable' })), /Could not verify your account: Network unavailable/);
    assert.equal((await check(client('admin'))).user.id, 'verified-user');
});

test('expired admin auth clears stale UI state and redirects to sign-in', async () => {
    let signedOut = false;
    await context.window.redirectExpiredAdminSession({ auth: { async signOut() { signedOut = true; } } });
    assert.equal(localStorage.getItem('irongrind_session'), null);
    assert.equal(sessionStorage.getItem('irongrind_session'), null);
    assert.equal(signedOut, true);
    assert.equal(redirectedTo, 'index.html?role=admin&auth=expired');
});
