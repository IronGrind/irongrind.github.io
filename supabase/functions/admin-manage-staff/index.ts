import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function response(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json', 'Cache-Control': 'no-store' },
  });
}

Deno.serve(async request => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (request.method !== 'POST') return response({ error: 'Method not allowed.' }, 405);

  const url = Deno.env.get('SUPABASE_URL');
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  const authorization = request.headers.get('Authorization');
  if (!url || !anonKey || !serviceRoleKey || !authorization) {
    return response({ error: 'Server configuration or admin session is missing.' }, 500);
  }

  const caller = createClient(url, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: authData, error: authError } = await caller.auth.getUser();
  if (authError || !authData.user) return response({ error: 'Sign in again to continue.' }, 401);
  const { data: profile, error: profileError } = await caller
    .from('profiles').select('role').eq('id', authData.user.id).maybeSingle();
  if (profileError || profile?.role !== 'admin') return response({ error: 'Admin access required.' }, 403);

  let body: Record<string, unknown>;
  try { body = await request.json(); }
  catch { return response({ error: 'Invalid request body.' }, 400); }

  const service = createClient(url, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const action = String(body.action || '');

  if (action === 'create') {
    const email = String(body.email || '').trim().toLowerCase();
    const username = String(body.username || '').trim().toLowerCase();
    const fullName = String(body.fullName || '').trim();
    const password = String(body.password || '');
    if (!email || email.length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)
      || !/^[a-z0-9_]{3,30}$/.test(username) || !fullName || fullName.length > 150
      || password.length < 8 || password.length > 72) {
      return response({ error: 'Enter a valid name, username, email, and an initial password of at least 8 characters.' }, 400);
    }

    const { data: created, error: createError } = await service.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: { username, full_name: fullName },
    });
    if (createError || !created.user) return response({ error: createError?.message || 'Could not create the staff account.' }, 400);

    const { error: updateError } = await service.from('profiles').update({
      username,
      full_name: fullName,
      role: 'staff',
      is_active: true,
    }).eq('id', created.user.id);
    if (updateError) {
      const { error: cleanupError } = await service.auth.admin.deleteUser(created.user.id);
      const cleanup = cleanupError ? ` Auth cleanup failed: ${cleanupError.message}` : '';
      return response({ error: `${updateError.message}${cleanup}` }, 400);
    }
    return response({ id: created.user.id, email, username, full_name: fullName, role: 'staff', is_active: true });
  }

  if (action === 'set_active') {
    const staffId = String(body.staffId || '');
    const isActive = body.isActive === true;
    if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(staffId)) {
      return response({ error: 'Select a valid staff account.' }, 400);
    }
    const { data: target, error: targetError } = await service.from('profiles')
      .select('id, role').eq('id', staffId).maybeSingle();
    if (targetError || target?.role !== 'staff') return response({ error: 'Staff account was not found.' }, 404);
    const { error: updateError } = await service.from('profiles')
      .update({ is_active: isActive }).eq('id', staffId);
    if (updateError) return response({ error: updateError.message }, 400);
    return response({ id: staffId, is_active: isActive });
  }

  return response({ error: 'Unknown staff-management action.' }, 400);
});
