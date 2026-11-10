import { createClient } from '@supabase/supabase-js';
import { isValidDateOnly, validateStaffMembershipTerms } from './validation.js';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function response(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}
function validPersonName(value: string) {
  const name = value.trim();
  return name.length > 0 && name.length <= 150 && /\p{L}/u.test(name) && !/[\p{N}\p{Cc}\p{Cf}]/u.test(name);
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (request.method !== 'POST') return response({ error: 'Method not allowed' }, 405);

  const url = Deno.env.get('SUPABASE_URL');
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  const authorization = request.headers.get('Authorization');
  if (!url || !anonKey || !serviceRoleKey || !authorization) {
    return response({ error: 'Server configuration or signed-in session is missing.' }, 500);
  }

  const callerClient = createClient(url, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: authData, error: authError } = await callerClient.auth.getUser();
  if (authError || !authData.user) return response({ error: 'Sign in again to continue.' }, 401);
  const { data: profile, error: profileError } = await callerClient
    .from('profiles').select('role,is_active').eq('id', authData.user.id).maybeSingle();
  if (profileError || !profile?.is_active || !['admin', 'staff'].includes(profile.role)) {
    return response({ error: 'Active admin or staff access required.' }, 403);
  }

  let body: Record<string, unknown>;
  try {
    body = await request.json();
  } catch {
    return response({ error: 'Invalid request body.' }, 400);
  }
  const email = String(body.email || '').trim().toLowerCase();
  const password = String(body.password || '');
  const fullName = String(body.fullName || '').trim();
  const mobile = String(body.mobile || '').trim();
  const emergencyContact = String(body.emergencyContact || '').trim();
  const emergencyName = String(body.emergencyName || '').trim();
  const plan = String(body.plan || '').trim();
  const price = Number(body.planPrice);
  const startDate = String(body.startDate || '');
  const expiryDate = String(body.expiryDate || '');
  if (password.length < 8 || password.length > 128 || !/[a-z]/.test(password) || !/[A-Z]/.test(password) || !/[0-9]/.test(password) || !/[^A-Za-z0-9\s]/.test(password)) {
    return response({ error: 'Use 8–128 characters with uppercase and lowercase letters, a number, and a symbol.' }, 400);
  }
  if (!email || password.length < 8 || !validPersonName(fullName) || !validPersonName(emergencyName) || !mobile || !plan
    || !Number.isFinite(price) || price <= 0 || !isValidDateOnly(startDate) || !isValidDateOnly(expiryDate) || expiryDate < startDate) {
    return response({ error: 'Required member or membership details are missing, or a name contains numbers or invalid characters.' }, 400);
  }
  if (!/^09\d{9}$/.test(mobile) || !/^09\d{9}$/.test(emergencyContact)) {
    return response({ error: 'Mobile and emergency contact numbers must each be 11 digits and start with 09.' }, 400);
  }
  if (profile.role === 'staff') {
    if (body.staffWalkinRegistration !== true || !validateStaffMembershipTerms({ plan, price, startDate, expiryDate })) {
      return response({ error: 'Staff registrations must use a standard plan, its exact price and duration, and today’s Philippine date.' }, 403);
    }
    if (typeof body.signatureData !== 'string' || !body.signatureData.startsWith('data:image/png;base64,')) {
      return response({ error: 'The member signature is required.' }, 400);
    }
  }

  const adminClient = createClient(url, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: emailAvailable, error: emailError } = await callerClient.rpc('is_registration_email_available', { p_email: email });
  if (emailError) return response({ error: 'Could not check email availability. Please try again.' }, 503);
  if (!emailAvailable) return response({ error: 'This email address is already registered. Use the existing account or choose another email.' }, 409);
  const { data: created, error: createError } = await adminClient.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: { full_name: fullName },
  });
  if (createError || !created.user) {
    return response({ error: createError?.message || 'Could not create Auth user.' }, 400);
  }

  const userId = created.user.id;
  const now = new Date().toISOString();
  const member = {
    auth_user_id: userId,
    full_name: fullName,
    email,
    username: null,
    mobile,
    date_of_birth: body.dateOfBirth || null,
    age: body.age ?? null,
    sex: body.sex || null,
    height: body.height || null,
    height_unit: body.heightUnit || null,
    weight_kg: body.weight || null,
    weight: body.weight || null,
    emergency_contact: {
      name: emergencyName,
      relationship: body.emergencyRelationship || '',
      contact: emergencyContact,
    },
    plan,
    plan_price: price,
    start_date: startDate,
    end_date: expiryDate,
    expiry_date: expiryDate,
    status: 'active',
    registration_source: profile.role === 'staff' ? 'Staff walk-in registration' : 'Admin registration',
    paid: price,
    fitness_goals: Array.isArray(body.fitnessGoals) ? body.fitnessGoals : [],
    health_conditions: Array.isArray(body.healthConditions) ? body.healthConditions : [],
    other_medical_conditions: String(body.otherMedicalConditions || ''),
    signature_path: body.signatureData || null,
    signature_data: body.signatureData || null,
    created_at: now,
    updated_at: now,
  };
  const receiptNumber = `IG-AR-${crypto.randomUUID().toUpperCase()}`;
  const { data: saved, error: saveError } = await adminClient.rpc('create_member_and_sale_with_actor', {
    p_actor_id: authData.user.id,
    p_member: member,
    p_receipt_number: receiptNumber,
  });

  if (saveError) {
    const { error: cleanupError } = await adminClient.auth.admin.deleteUser(userId);
    const cleanupMessage = cleanupError
      ? ` The Auth account could not be removed automatically (${cleanupError.message}); delete it from Auth > Users if needed.`
      : '';
    return response({ error: `${saveError.message}${cleanupMessage}` }, 400);
  }
  return response({ ...saved, email, full_name: fullName });
});
