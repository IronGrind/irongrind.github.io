import { createClient } from '@supabase/supabase-js';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};
const invalidCredentials = 'Invalid username or password.';
const respond = (body: unknown, status = 200) => new Response(JSON.stringify(body), {
  status, headers: { ...corsHeaders, 'Content-Type': 'application/json', 'Cache-Control': 'no-store' },
});

export async function handleAdminLogin(request: Request) {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (request.method !== 'POST') return respond({ error: 'Method not allowed.' }, 405);
  const url = Deno.env.get('SUPABASE_URL');
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!url || !anonKey || !serviceKey) return respond({ error: 'Admin sign-in is not configured.' }, 503);
  let input;
  try {
    const raw = await request.text();
    if (raw.length > 8192) return respond({ error: invalidCredentials }, 400);
    input = JSON.parse(raw);
  } catch { return respond({ error: invalidCredentials }, 400); }
  const username = typeof input?.username === 'string' ? input.username.trim().toLowerCase() : '';
  const password = typeof input?.password === 'string' ? input.password : '';
  if (!username || username.length > 30 || username.includes('@') || !password || password.length > 1024) {
    return respond({ error: invalidCredentials }, 400);
  }
  const settings = { auth: { persistSession: false, autoRefreshToken: false } };
  const admin = createClient(url, serviceKey, settings);
  const login = createClient(url, anonKey, settings);
  try {
    const hash = async (value: string) => Array.from(new Uint8Array(await crypto.subtle.digest(
      'SHA-256', new TextEncoder().encode(`${serviceKey}:${value}`),
    ))).map(value => value.toString(16).padStart(2, '0')).join('');
    const ip = request.headers.get('x-forwarded-for')?.split(',')[0]?.trim() || 'unknown';
    for (const [bucket, limit] of [[`user:${await hash(username)}`, 10], [`ip:${await hash(ip)}`, 50]] as const) {
      const { data, error } = await admin.rpc('consume_admin_login_attempt', { p_bucket: bucket, p_limit: limit });
      if (error) return respond({ error: 'Admin sign-in is unavailable. Contact the gym administrator.' }, 503);
      if (data !== true) return respond({ error: 'Too many sign-in attempts. Please wait five minutes and try again.' }, 429);
    }
    // Escape LIKE wildcards: this is an exact, case-insensitive username match.
    const pattern = username.replace(/[\\%_]/g, '\\$&');
    const { data: profile, error: profileError } = await admin.from('profiles')
      .select('id,role').in('role', ['admin', 'staff']).ilike('username', pattern).maybeSingle();
    if (profileError) {
      console.error('Admin username lookup failed:', profileError.code);
      return respond({ error: 'Username sign-in is unavailable. Contact the gym administrator.' }, 503);
    }
    // Unknown usernames use the same Auth password check and failure response.
    const { data: account, error: accountError } = profile
      ? await admin.auth.admin.getUserById(profile.id)
      : { data: { user: null }, error: null };
    if (accountError) {
      console.error('Admin Auth account lookup failed:', accountError.code);
      return respond({ error: 'Username sign-in is unavailable. Contact the gym administrator.' }, 503);
    }
    const email = account?.user?.email || 'invalid-admin-login@example.invalid';
    const { data, error } = await login.auth.signInWithPassword({ email, password });
    if (error || !data.session || !profile || data.user?.id !== profile.id) {
      if (data.session) await login.auth.signOut();
      return respond({ error: invalidCredentials }, 401);
    }
    const { data: verified, error: roleError } = await admin.from('profiles')
      .select('role').eq('id', data.user.id).single();
    if (roleError || !['admin', 'staff'].includes(verified?.role || '')) {
      await login.auth.signOut();
      if (roleError) {
        console.error('Admin role lookup failed:', roleError.code);
        return respond({ error: 'Username sign-in is unavailable. Contact the gym administrator.' }, 503);
      }
      return respond({ error: invalidCredentials }, 401);
    }
    if (verified.role === 'staff') {
      const { data: staffStatus, error: staffStatusError } = await admin.from('profiles')
        .select('is_active').eq('id', data.user.id).single();
      if (staffStatusError) {
        await login.auth.signOut();
        console.error('Staff status lookup failed:', staffStatusError.code);
        return respond({ error: 'Staff sign-in is unavailable until the staff role migration is applied.' }, 503);
      }
      if (staffStatus?.is_active !== true) {
        await login.auth.signOut();
        return respond({ error: invalidCredentials }, 401);
      }
    }
    return respond({ session: { access_token: data.session.access_token, refresh_token: data.session.refresh_token } });
  } catch {
    return respond({ error: 'Unable to connect to admin sign-in. Please try again.' }, 503);
  }
}
