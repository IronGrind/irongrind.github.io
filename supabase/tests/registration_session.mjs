// Exercises the real browser SDK with fake Auth responses; creates no accounts.
// An optional SDK file path avoids downloading the site's CDN dependency again.
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import vm from 'node:vm';

const sdk = process.argv[2]
    ? await readFile(process.argv[2], 'utf8')
    : await (await fetch('https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2')).text();
const configuration = await readFile(new URL('../../assets/js/supabase-client.js', import.meta.url), 'utf8');
const storage = new Map();
const localStorage = {
    getItem: key => storage.get(key) ?? null,
    setItem: (key, value) => storage.set(key, String(value)),
    removeItem: key => storage.delete(key)
};
const adminId = '11111111-1111-4111-8111-111111111111';
const memberId = '22222222-2222-4222-8222-222222222222';
const user = id => ({ id, aud: 'authenticated', role: 'authenticated', email: `${id}@example.test`, app_metadata: {}, user_metadata: {}, identities: [] });
const token = id => [
    { alg: 'HS256', typ: 'JWT' },
    { sub: id, exp: Math.floor(Date.now() / 1000) + 3600, role: 'authenticated' }
].map(part => Buffer.from(JSON.stringify(part)).toString('base64url')).join('.') + '.test';
const session = id => ({ access_token: token(id), refresh_token: `refresh-${id}`, expires_in: 3600, token_type: 'bearer', user: user(id) });

function page(registration, hash = '') {
    const document = {
        body: { classList: { contains: name => registration && name === 'register-body' } },
        visibilityState: 'visible', addEventListener() {}, removeEventListener() {}
    };
    const location = new URL(`https://example.test/${registration ? 'register' : 'admin'}.html${hash}`);
    const window = { document, location, localStorage, addEventListener() {}, removeEventListener() {} };
    const context = vm.createContext({
        window, document, location, localStorage, console, URL, URLSearchParams, navigator: { onLine: true },
        Headers, Request, Response, TextEncoder, TextDecoder, AbortController, WebSocket,
        crypto: globalThis.crypto, atob, btoa,
        setTimeout, clearTimeout, setInterval: (...args) => { const timer = setInterval(...args); timer.unref(); return timer; }, clearInterval,
        async fetch(input) {
            const url = String(input);
            if (url.includes('/auth/v1/token')) return Response.json(session(adminId));
            if (url.includes('/auth/v1/signup')) return Response.json(session(memberId));
            if (url.includes('/auth/v1/user')) return Response.json(user(memberId));
            if (url.includes('/rest/v1/rpc/current_account_session_is_active')) return Response.json(true);
            throw new Error(`Unexpected network request: ${url}`);
        }
    });
    vm.runInContext(sdk, context);
    window.supabase = context.supabase;
    vm.runInContext(configuration, context);
    return window.ironGrindSupabase;
}

const admin = page(false);
const login = await admin.auth.signInWithPassword({ email: 'admin@example.test', password: 'fixture-only' });
assert.equal(login.error, null);
// Reproduce the original problem before testing the registration-only client.
const previousRegistration = page(false);
await previousRegistration.auth.signUp({ email: 'member@example.test', password: 'fixture-only' });
assert.equal((await admin.auth.getSession()).data.session.user.id, memberId, 'A shared signup client replaces the admin session');
await admin.auth.signInWithPassword({ email: 'admin@example.test', password: 'fixture-only' });
const adminStorage = Array.from(storage.entries());
assert.ok(adminStorage.length > 0, 'Normal login must retain its session');

const registration = page(true);
const signup = await registration.auth.signUp({ email: 'member@example.test', password: 'fixture-only' });
assert.equal(signup.error, null);
assert.equal((await registration.auth.getSession()).data.session.user.id, memberId);
assert.deepEqual(Array.from(storage.entries()), adminStorage, 'Registration must not overwrite the admin session');
assert.equal((await admin.auth.getSession()).data.session.user.id, adminId);

const callback = page(true, `#access_token=${token(memberId)}&refresh_token=confirmation-token&expires_in=3600&token_type=bearer&type=signup`);
const confirmed = await callback.auth.getSession();
assert.equal(confirmed.error, null);
assert.equal(confirmed.data.session?.user.id, memberId, 'Email confirmation must still authenticate the application submission');
assert.deepEqual(Array.from(storage.entries()), adminStorage, 'Email confirmation must also leave the admin session intact');

for (const client of [admin, previousRegistration, registration, callback]) client.auth.stopAutoRefresh();
console.log('Passed: signup and email confirmation retain their temporary member session without replacing a signed-in admin in the same browser.');
