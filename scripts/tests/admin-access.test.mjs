import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';
import test from 'node:test';
const context = vm.createContext({ window: {} });
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
