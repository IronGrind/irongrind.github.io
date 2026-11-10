import { createClient } from '@supabase/supabase-js';
const headers = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type', 'Access-Control-Allow-Methods': 'POST, OPTIONS' };
const respond = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { ...headers, 'Content-Type': 'application/json', 'Cache-Control': 'no-store' } });
Deno.serve(async request => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers });
  if (request.method !== 'POST') return respond({ error: 'Method not allowed.' }, 405);
  const url = Deno.env.get('SUPABASE_URL'), anon = Deno.env.get('SUPABASE_ANON_KEY'), service = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!url || !anon || !service) return respond({ error: 'Sign-in is unavailable.' }, 503);
  try {
    const raw = await request.text();
    if (raw.length > 8192) return respond({ error: 'Invalid email or password.' }, 400);
    const input = JSON.parse(raw);
    const email = typeof input.email === 'string' ? input.email.trim().toLowerCase() : '';
    const password = typeof input.password === 'string' ? input.password : '';
    if (!email || email.length > 254 || !password || password.length > 1024) return respond({ error: 'Invalid email or password.' }, 400);
    const options = { auth: { persistSession: false, autoRefreshToken: false } };
    const admin = createClient(url, service, options), login = createClient(url, anon, options);
    const hash = async (value: string) => Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(`${service}:${value}`)))).map(v => v.toString(16).padStart(2, '0')).join('');
    const ip = request.headers.get('x-forwarded-for')?.split(',')[0]?.trim() || 'unknown';
    for (const [bucket, limit] of [[`user:${await hash(`member:${email}`)}`, 10], [`ip:${await hash(ip)}`, 50]] as const) {
      const { data, error } = await admin.rpc('consume_admin_login_attempt', { p_bucket: bucket, p_limit: limit });
      if (error) return respond({ error: 'Sign-in is unavailable.' }, 503);
      if (data !== true) {
        await admin.rpc('record_security_failure', { p_event: 'sign_in_throttled' });
        return respond({ error: 'Too many sign-in attempts. Please wait five minutes.' }, 429);
      }
    }
    const { data, error } = await login.auth.signInWithPassword({ email, password });
    if (error || !data.session) {
      const audit = await admin.rpc('record_security_failure', { p_event: 'member_sign_in_failed' });
      if (audit.error) console.error('Member failure audit unavailable:', audit.error.code);
      return respond({ error: 'Invalid email or password.', code: error?.code }, 401);
    }
    return respond({ session: { access_token: data.session.access_token, refresh_token: data.session.refresh_token } });
  } catch { return respond({ error: 'Unable to sign in. Please try again.' }, 503); }
});
