import { createClient } from 'npm:@supabase/supabase-js@2';
const headers = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type', 'Access-Control-Allow-Methods': 'POST, OPTIONS' };
const reply = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { ...headers, 'Content-Type': 'application/json', 'Cache-Control': 'no-store' } });
Deno.serve(async request => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers });
  if (request.method !== 'POST') return reply({ error: 'Method not allowed.' }, 405);
  try {
    const url = Deno.env.get('SUPABASE_URL'), anon = Deno.env.get('SUPABASE_ANON_KEY'), service = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    if (!url || !anon || !service) return reply({ error: 'Member device approval is unavailable.' }, 503);
    const authorization = request.headers.get('Authorization') || '';
    const client = createClient(url, anon, { global: { headers: { Authorization: authorization } }, auth: { persistSession: false, autoRefreshToken: false } });
    const { data: { user }, error: identityError } = await client.auth.getUser();
    if (identityError || !user) return reply({ error: 'Sign in again.' }, 401);
    const token = authorization.replace(/^Bearer\s+/i, ''), encoded = token.split('.')[1];
    if (!encoded) return reply({ error: 'Invalid session.' }, 401);
    const claims = JSON.parse(atob(encoded.replace(/-/g, '+').replace(/_/g, '/')));
    if (claims.sub !== user.id || typeof claims.session_id !== 'string') return reply({ error: 'Invalid session.' }, 401);
    const raw = await request.text();
    if (raw.length > 8192) return reply({ error: 'Request too large.' }, 400);
    const body = JSON.parse(raw), admin = createClient(url, service, { auth: { persistSession: false, autoRefreshToken: false } });
    if (body.action === 'challenge') {
      const { data, error } = await admin.rpc('create_member_device_challenge', {
        p_user: user.id, p_session: claims.session_id, p_device: body.deviceId, p_key: body.publicKey
      });
      if (error) return reply({ error: 'Could not prepare member device verification. Confirm that the migration is deployed.' }, 403);
      if (data?.skip === true) return reply({ skip: true });
      return reply(data);
    }
    if (body.action === 'status') {
      const { data, error } = await admin.rpc('get_member_device_approval_status', { p_user: user.id, p_session: claims.session_id });
      if (error) return reply({ error: 'Could not check the member device approval.' }, 403);
      return reply(data || { status: 'none' });
    }
    if (body.action !== 'complete') return reply({ error: 'Unsupported action.' }, 400);
    const { data: challenge, error: challengeError } = await admin.rpc('get_member_device_challenge', { p_user: user.id, p_session: claims.session_id });
    if (challengeError || !challenge) return reply({ error: 'Device verification expired. Sign in again.' }, 403);
    if (typeof body.signature !== 'string' || body.signature.length > 256) return reply({ error: 'Invalid device proof.' }, 403);
    const key = await crypto.subtle.importKey('jwk', challenge.public_key, { name: 'ECDSA', namedCurve: 'P-256' }, false, ['verify']);
    const signature = Uint8Array.from(atob(body.signature), character => character.charCodeAt(0));
    if (!await crypto.subtle.verify({ name: 'ECDSA', hash: 'SHA-256' }, key, signature, new TextEncoder().encode(challenge.message))) return reply({ error: 'Device proof was not accepted.' }, 403);
    const { data, error } = await admin.rpc('finish_member_device_login', {
      p_user: user.id, p_session: claims.session_id, p_challenge: challenge.message,
      p_label: typeof body.label === 'string' ? body.label.slice(0, 180) : 'Browser'
    });
    if (error) return reply({ error: 'Could not register this member device. Sign in again or contact the gym.' }, 403);
    return reply(data || { status: 'authorized' });
  } catch {
    return reply({ error: 'Member device verification could not complete. Check your connection and sign in again.' }, 400);
  }
});
