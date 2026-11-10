import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import { stripTypeScriptTypes } from 'node:module';
import { webcrypto } from 'node:crypto';
import test from 'node:test';
const source = stripTypeScriptTypes(fs.readFileSync('supabase/functions/member-password-login/index.ts', 'utf8').replace(/^import .*\n/, ''));
function setup({ failure = false, throttle = false } = {}) {
    const events = [];
    const admin = { rpc: async (name, args) => {
        if (name === 'consume_admin_login_attempt') {
            assert.match(args.p_bucket, /^(user|ip):[a-f0-9]{64}$/);
            return { data: !throttle };
        }
        events.push(args.p_event); return {};
    } };
    const login = { auth: { signInWithPassword: async () => failure ? { data: {}, error: { code: 'invalid_credentials' } } : { data: { session: { access_token: 'access', refresh_token: 'refresh' } } } } };
    let handler;
    vm.runInNewContext(source, { Response, TextEncoder, crypto: webcrypto, console,
        createClient: (_, key) => key === 'SUPABASE_SERVICE_ROLE_KEY' ? admin : login,
        Deno: { env: { get: key => key }, serve: fn => { handler = fn; } }
    });
    return { events, run: () => handler(new Request('https://example.invalid', { method: 'POST', body: JSON.stringify({ email: 'member@example.test', password: 'private-password' }) })) };
}
test('member credential rejection is audited without credentials', async () => {
    const fixture = setup({ failure: true }); const response = await fixture.run();
    assert.equal(response.status, 401); assert.deepEqual(fixture.events, ['member_sign_in_failed']);
});
test('member throttle is enforced and audited', async () => {
    const fixture = setup({ throttle: true }); assert.equal((await fixture.run()).status, 429);
    assert.deepEqual(fixture.events, ['sign_in_throttled']);
});
test('successful member login returns session without a false failure event', async () => {
    const fixture = setup(); const response = await fixture.run();
    assert.equal(response.status, 200); assert.equal((await response.json()).session.access_token, 'access');
    assert.deepEqual(fixture.events, []);
});
