import { createClient } from '@supabase/supabase-js';

const headers = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type', 'Access-Control-Allow-Methods': 'POST, OPTIONS', 'Content-Type': 'application/json', 'Cache-Control': 'no-store' };
const reply = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers });
Deno.serve(async request => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers });
  if (request.method !== 'POST') return reply({ error: 'Method not allowed.' }, 405);
  try {
    const url = Deno.env.get('SUPABASE_URL')!;
    const caller = createClient(url, Deno.env.get('SUPABASE_ANON_KEY')!, {
      global: { headers: { Authorization: request.headers.get('Authorization') || '' } },
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: { user }, error } = await caller.auth.getUser();
    if (error || !user) return reply({ error: 'Sign in again.' }, 401);
    const { data: profile, error: profileError } = await caller.from('profiles').select('role,is_active').eq('id', user.id).single();
    if (profileError || profile?.role !== 'admin' || !profile.is_active) return reply({ error: 'Active admin access required.' }, 403);
    let body;
    try { body = await request.json(); } catch { return reply({ error: 'Invalid request.' }, 400); }
    const action = typeof body.action === 'string' ? body.action : 'create';
    const admin = createClient(url, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, { auth: { persistSession: false, autoRefreshToken: false } });
    if (action === 'list') {
      const { data: staff, error: listError } = await admin.from('profiles')
        .select('id,email,username,full_name,phone_number,gender,is_active,created_at').eq('role', 'staff').order('created_at', { ascending: false });
      if (listError) return reply({ error: 'Could not load staff accounts.' }, 500);
      return reply({ staff: staff || [] });
    }
    if (action === 'set_active') {
      const id = typeof body.id === 'string' ? body.id : '';
      const isActive = body.isActive === true;
      if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(id)) return reply({ error: 'Invalid staff account.' }, 400);
      const { data: updated, error: updateError } = await admin.from('profiles').update({ is_active: isActive })
        .eq('id', id).eq('role', 'staff').select('id').maybeSingle();
      if (updateError || !updated) return reply({ error: 'Could not update the staff account.' }, 500);
      return reply({ id, isActive });
    }
    if (action !== 'create') return reply({ error: 'Unsupported staff account action.' }, 400);
    const username = typeof body.username === 'string' ? body.username.trim().toLowerCase() : '';
    const fullName = typeof body.fullName === 'string' ? body.fullName.trim() : '';
    const email = typeof body.email === 'string' ? body.email.trim().toLowerCase() : '';
    const phoneNumber = typeof body.phoneNumber === 'string' ? body.phoneNumber.replace(/\D/g, '') : '';
    const gender = typeof body.gender === 'string' ? body.gender.trim() : '';
    const password = typeof body.password === 'string' ? body.password : '';
    if (!/^[a-z0-9_]{3,30}$/.test(username) || !fullName || fullName.length > 150 || password.length < 12 || password.length > 128 || !/[a-z]/.test(password) || !/[A-Z]/.test(password) || !/[0-9]/.test(password) || !/[^A-Za-z0-9\s]/.test(password)) {
      return reply({ error: 'Enter a name, a 3–30 character username, and a password of 12–128 characters containing uppercase and lowercase letters, a number, and a symbol.' }, 400);
    }
    if (!/^[a-z0-9._%+-]+@gmail\.com$/.test(email)) return reply({ error: 'Enter a valid Gmail address ending in @gmail.com.' }, 400);
    if (!/^9\d{9}$/.test(phoneNumber)) return reply({ error: 'Enter a 10-digit mobile number beginning with 9 after +63.' }, 400);
    if (!['Female', 'Male', 'Prefer not to say'].includes(gender)) return reply({ error: 'Select a gender.' }, 400);
    const { data: emailAvailable, error: emailError } = await admin.rpc('is_registration_email_available', { p_email: email });
    if (emailError) return reply({ error: 'Could not check email availability. Please try again.' }, 503);
    if (!emailAvailable) return reply({ error: 'This email address is already registered. Use another email for the staff account.' }, 409);
    const { data: available, error: usernameError } = await admin.rpc('is_registration_username_available', { p_username: username });
    if (usernameError) return reply({ error: 'Could not check username availability. Please try again.' }, 503);
    if (!available) return reply({ error: 'That username is already in use. Choose another username.' }, 409);
    const { data: created, error: createError } = await admin.auth.admin.createUser({
      email, password, email_confirm: true,
      user_metadata: { username, full_name: fullName, phone_number: `+63${phoneNumber}`, gender },
    });
    if (createError || !created.user) return reply({ error: 'Could not create staff account. The username may already be in use.' }, 400);
    const { data: saved, error: saveError } = await admin.from('profiles').update({
      role: 'staff', is_active: true, phone_number: `+63${phoneNumber}`, gender,
    }).eq('id', created.user.id).select('id').single();
    if (saveError || !saved) {
      const { error: cleanupError } = await admin.auth.admin.deleteUser(created.user.id);
      if (cleanupError) console.error('Staff account cleanup failed:', created.user.id);
      return reply({ error: 'Could not assign staff access.' }, 500);
    }
    return reply({ username }, 201);
  } catch { return reply({ error: 'Staff account service is unavailable.' }, 500); }
});
