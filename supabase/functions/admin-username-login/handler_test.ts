import { handleAdminLogin } from './handler.ts';

function assert(condition: unknown, message: string): asserts condition {
  if (!condition) throw new Error(message);
}

Deno.test('admin username endpoint validates credentials, role, privacy, and throttling', async () => {
  const names = ['SUPABASE_URL', 'SUPABASE_ANON_KEY', 'SUPABASE_SERVICE_ROLE_KEY'];
  const saved = names.map(name => Deno.env.get(name));
  Deno.env.set(names[0], 'https://example.invalid');
  Deno.env.set(names[1], 'test-anon-key');
  Deno.env.set(names[2], 'test-service-key');
  const originalFetch = globalThis.fetch;
  const userId = '11111111-1111-4111-8111-111111111111';
  let scenario = 'success';
  let passwordChecks = 0;
  let receivedPattern = '';
  let usedAuthEmail = '';
  globalThis.fetch = (input, init) => {
    const url = new URL(input instanceof Request ? input.url : String(input));
    const body = init?.body ? JSON.parse(String(init.body)) : {};
    let payload: unknown;
    let status = 200;
    if (url.pathname.endsWith('/rpc/consume_admin_login_attempt')) {
      assert(/^(user|ip):[a-f0-9]{64}$/.test(body.p_bucket), 'Only hashed throttle identities');
      payload = scenario !== 'limited';
      if (scenario === 'setup-error') { payload = { code: 'PGRST202' }; status = 404; }
    } else if (url.pathname.endsWith('/profiles')) {
      if (scenario === 'profile-permission-error') {
        return Promise.resolve(new Response(JSON.stringify({ code: '42501', message: 'permission denied for table profiles' }), { status: 403, headers: { 'Content-Type': 'application/json' } }));
      }
      if (url.searchParams.get('select') === 'id') {
        receivedPattern = url.searchParams.get('username') || '';
        assert(url.searchParams.get('role') === 'in.(admin,staff)' && url.searchParams.get('is_active') === 'eq.true', 'Lookup restricts active admin and staff roles');
        payload = scenario === 'unknown' || scenario === 'member' ? [] : [{ id: userId }];
      } else payload = { role: scenario === 'demoted' ? 'member' : scenario === 'staff' ? 'staff' : 'admin', is_active: scenario !== 'inactive' };
    } else if (url.pathname.endsWith(`/admin/users/${userId}`)) {
      payload = { id: userId, email: 'private-staff@example.test' };
    } else if (url.pathname.endsWith('/token')) {
      passwordChecks++;
      usedAuthEmail = body.email;
      if (scenario === 'wrong' || scenario === 'unknown' || scenario === 'member') {
        status = 400;
        payload = { code: 'invalid_credentials', message: 'Invalid login credentials' };
      } else payload = { access_token: 'test-access', refresh_token: 'test-refresh', expires_in: 3600, token_type: 'bearer', user: { id: userId, email: 'private-staff@example.test' } };
    } else if (url.pathname.endsWith('/logout')) payload = {};
    else throw new Error(`Unexpected network path: ${url.pathname}`);
    return Promise.resolve(new Response(JSON.stringify(payload), { status, headers: { 'Content-Type': 'application/json' } }));
  };
  const attempt = (username = ' Staff_One% ', password = 'test-password') => handleAdminLogin(new Request('https://example.invalid/login', {
    method: 'POST', body: JSON.stringify({ username, password }), headers: { 'x-forwarded-for': '192.0.2.1' },
  }));
  try {
    let response = await attempt();
    let body = await response.json();
    assert(response.status === 200 && body.session?.access_token === 'test-access', 'Admin receives session');
    assert(!JSON.stringify(body).includes('private-staff'), 'Email is not returned by lookup');
    assert(usedAuthEmail === 'private-staff@example.test', 'Authenticates using server-side Auth email');
    assert(receivedPattern === 'ilike.staff\\_one\\%', 'Exact case-insensitive lookup escapes wildcard characters');
    scenario = 'staff';
    response = await attempt(); body = await response.json();
    assert(response.status === 200 && body.session, 'Staff receives a session');
    const invalidBodies = [];
    for (scenario of ['wrong', 'unknown', 'member', 'demoted', 'inactive']) {
      response = await attempt(); body = await response.json();
      assert(response.status === 401 && !body.session, `${scenario} cannot receive a session`);
      invalidBodies.push(body.error);
    }
    assert(new Set(invalidBodies).size === 1, 'Failures share a generic credential message');
    scenario = 'limited';
    const checksBefore = passwordChecks;
    response = await attempt();
    assert(response.status === 429 && passwordChecks === checksBefore, 'Throttle blocks before password authentication');
    scenario = 'setup-error';
    response = await attempt();
    assert(response.status === 503, 'Missing migration fails closed');
    scenario = 'profile-permission-error';
    const passwordChecksBeforePermissionError = passwordChecks;
    response = await attempt();
    assert(response.status === 503 && passwordChecks === passwordChecksBeforePermissionError, 'Profile permission failures report service unavailability before checking passwords');
    response = await attempt('staff@example.test');
    assert(response.status === 400, 'Admin form endpoint rejects email identifiers');
    response = await handleAdminLogin(new Request('https://example.invalid/login', { method: 'OPTIONS' }));
    assert(response.status === 200, 'CORS preflight supported');
  } finally {
    globalThis.fetch = originalFetch;
    names.forEach((name, i) => saved[i] === undefined ? Deno.env.delete(name) : Deno.env.set(name, saved[i]!));
  }
});
