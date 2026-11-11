import { createClient } from 'npm:@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};
const respond = (body: unknown, status = 200) => new Response(JSON.stringify(body), {
  status,
  headers: { ...corsHeaders, 'Content-Type': 'application/json', 'Cache-Control': 'no-store' },
});
const plans = Object.freeze({ Monthly: { price: 800, days: 30 }, 'Half Month': { price: 400, days: 15 }, 'Walk-in': { price: 80, days: 1 } });
const allowedGoals = new Set(['Weight Loss', 'Muscle Gain', 'Strength', 'General Fitness']);
const allowedConditions = new Set(['High Blood Pressure', 'Heart Condition', 'Asthma', 'Recent Injury']);

function validName(value: unknown) {
  if (typeof value !== 'string') return false;
  const name = value.trim();
  return name.length > 0 && name.length <= 150 && /\p{L}/u.test(name) && !/[\p{N}\p{Cc}\p{Cf}]/u.test(name);
}
function validDate(value: unknown) {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const date = new Date(`${value}T00:00:00.000Z`);
  return Number.isFinite(date.getTime()) && date.toISOString().slice(0, 10) === value;
}
function manilaDate(date = new Date()) {
  const parts = new Intl.DateTimeFormat('en', { timeZone: 'Asia/Manila', year: 'numeric', month: '2-digit', day: '2-digit' }).formatToParts(date);
  return ['year', 'month', 'day'].map(type => parts.find(part => part.type === type)!.value).join('-');
}
function addDays(value: string, days: number) {
  const [year, month, day] = value.split('-').map(Number);
  return new Date(Date.UTC(year, month - 1, day + days)).toISOString().slice(0, 10);
}
function ageOnDate(dob: string, today: string) {
  const [by, bm, bd] = dob.split('-').map(Number);
  const [ty, tm, td] = today.split('-').map(Number);
  return ty - by - (tm < bm || (tm === bm && td < bd) ? 1 : 0);
}
async function sha256(value: string) {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(value));
  return Array.from(new Uint8Array(digest)).map(byte => byte.toString(16).padStart(2, '0')).join('');
}
function validate(body: Record<string, unknown>) {
  const app = body.application as Record<string, unknown> | null;
  const email = typeof body.email === 'string' ? body.email.trim().toLowerCase() : '';
  const password = typeof body.password === 'string' ? body.password : '';
  if (!app || typeof app !== 'object') return { error: 'Application details are missing.' };
  if (email.length < 3 || email.length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) return { error: 'Enter a valid email address.' };
  if (password.length < 8 || password.length > 128 || !/[a-z]/.test(password) || !/[A-Z]/.test(password) || !/[0-9]/.test(password) || !/[^A-Za-z0-9\s]/.test(password)) return { error: 'Use a password with uppercase and lowercase letters, a number, and a symbol.' };
  if (body.acceptedRules !== true || body.acceptedWaiver !== true) return { error: 'Accept the gym rules and liability waiver before submitting.' };
  if (!validName(app.fullName) || !validDate(app.dob) || !validName((app.emergencyContact as Record<string, unknown> | null)?.name)) return { error: 'Check the applicant name, date of birth and emergency contact name.' };
  const today = manilaDate();
  const dob = String(app.dob);
  const computedAge = ageOnDate(dob, today);
  if (dob >= today || computedAge < 12 || computedAge > 120 || Number(app.age) !== computedAge) return { error: 'The date of birth and age are invalid. Applicants must be at least 12 years old.' };
  if (!['Male', 'Female', 'Prefer not to say'].includes(String(app.sex))) return { error: 'Select a valid sex option.' };
  if (typeof app.mobile !== 'string' || !/^09\d{9}$/.test(app.mobile)) return { error: 'Enter a valid Philippine mobile number.' };
  const emergency = app.emergencyContact as Record<string, unknown>;
  if (typeof emergency.relationship !== 'string' || !emergency.relationship.trim() || emergency.relationship.length > 100
    || typeof emergency.contact !== 'string' || !/^09\d{9}$/.test(emergency.contact)) return { error: 'Check the emergency contact relationship and number.' };
  const height = app.height == null ? null : Number(app.height);
  const heightUnit = app.heightUnit == null ? null : String(app.heightUnit);
  const weight = app.weight == null ? null : Number(app.weight);
  if ((height != null && (!Number.isFinite(height) || height <= 0 || height > 300))
    || (height != null && !['cm', 'ft'].includes(String(heightUnit)))
    || (height == null && heightUnit != null)
    || (weight != null && (!Number.isFinite(weight) || weight <= 0 || weight > 1000))) return { error: 'Check the height and weight values.' };
  const plan = plans[String(app.plan) as keyof typeof plans];
  if (!plan || Number(app.planPrice) !== plan.price || !validDate(app.startDate) || !validDate(app.endDate)
    || app.startDate !== today || app.endDate !== addDays(today, plan.days)) return { error: 'The membership plan, price or dates are invalid. Refresh the form and try again.' };
  const goals = Array.isArray(app.goals) ? app.goals : [];
  const conditions = Array.isArray(app.healthConditions) ? app.healthConditions : [];
  if (goals.some(item => typeof item !== 'string' || !allowedGoals.has(item))
    || conditions.some(item => typeof item !== 'string' || !allowedConditions.has(item))) return { error: 'The fitness or health selections are invalid.' };
  const other = typeof app.otherMedicalConditions === 'string' ? app.otherMedicalConditions.trim() : '';
  if (other.length > 500 || (app.otherMedicalConditions && typeof app.otherMedicalConditions !== 'string')) return { error: 'Other medical details must be 500 characters or fewer.' };
  const signature = typeof app.signature === 'string' ? app.signature : '';
  if (!/^data:image\/png;base64,[A-Za-z0-9+/]+={0,2}$/.test(signature) || signature.length > 2_000_000) return { error: 'A valid signature is required.' };
  return { app, email, password, height, heightUnit, weight, goals, conditions, other, emergency, signature };
}

Deno.serve(async request => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (request.method !== 'POST') return respond({ error: 'Method not allowed.' }, 405);
  const url = Deno.env.get('SUPABASE_URL'), anon = Deno.env.get('SUPABASE_ANON_KEY'), service = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!url || !anon || !service) return respond({ error: 'Registration service is unavailable.' }, 503);
  try {
    const raw = await request.text();
    if (raw.length > 3_000_000) return respond({ error: 'The application is too large.' }, 413);
    const body = JSON.parse(raw) as Record<string, unknown>;
    const valid = validate(body);
    if ('error' in valid) return respond({ error: valid.error }, 400);
    const { app, email, password, height, heightUnit, weight, goals, conditions, other, emergency, signature } = valid;
    const admin = createClient(url, service, { auth: { persistSession: false, autoRefreshToken: false } });
    const ip = request.headers.get('x-forwarded-for')?.split(',')[0]?.trim() || 'unknown';
    for (const [bucket, value, limit] of [['user', `member-registration:${email}`, 10], ['ip', ip, 50]] as const) {
      const { data, error } = await admin.rpc('consume_admin_login_attempt', { p_bucket: `${bucket}:${await sha256(`${service}:${value}`)}`, p_limit: limit });
      if (error) return respond({ error: 'Registration service is unavailable.' }, 503);
      if (data !== true) return respond({ error: 'Too many registration attempts. Wait five minutes and try again.' }, 429);
    }
    const { data: available, error: availabilityError } = await admin.rpc('is_registration_email_available', { p_email: email });
    if (availabilityError) return respond({ error: 'Could not verify this email. Please try again.' }, 503);
    if (!available) return respond({ code: 'EMAIL_IN_USE', error: 'This email is already associated with an account. Sign in or use Forgot Password to continue.' }, 409);

    const mailClient = createClient(url, anon, { auth: { persistSession: false, autoRefreshToken: false } });
    const { data: signup, error: signupError } = await mailClient.auth.signUp({
      email,
      password,
      options: {
        data: { full_name: app.fullName },
        emailRedirectTo: 'https://irongrind.vercel.app/register.html?completeApplication=1',
      },
    });
    if (signupError || !signup.user || (Array.isArray(signup.user.identities) && signup.user.identities.length === 0)) {
      if (!signupError && signup.user?.identities?.length === 0) return respond({ code: 'EMAIL_IN_USE', error: 'This email is already associated with an account. Sign in or use Forgot Password to continue.' }, 409);
      return respond({ error: signupError?.message || 'The account could not be created. No application was saved.' }, 400);
    }
    const userId = signup.user.id;
    const row = {
      auth_user_id: userId, member_id: null, application_type: 'registration',
      full_name: app.fullName, email, mobile: app.mobile, date_of_birth: app.dob, age: app.age, sex: app.sex,
      height, height_unit: heightUnit, weight_kg: weight, emergency_contact_data: emergency,
      plan: app.plan, plan_price: app.planPrice, start_date: app.startDate, end_date: app.endDate,
      fitness_goals: goals, health_conditions: conditions, other_medical_conditions: other,
      signature_path: signature, status: 'pending', submitted_at: new Date().toISOString(), reviewed_at: null, reviewed_by: null,
    };
    const { data: saved, error: saveError } = await admin.from('membership_applications').insert(row).select('id').single();
    if (saveError || !saved?.id) {
      const { error: cleanupError } = await admin.auth.admin.deleteUser(userId);
      console.error('Member application insert failed:', saveError?.code || 'unknown', 'Auth rollback:', cleanupError?.code || 'ok');
      return respond({ error: cleanupError
        ? 'The application could not be saved, and automatic account cleanup failed. Contact gym staff to remove the incomplete account.'
        : 'The application could not be saved. The new account was removed; please try again.' }, 500);
    }
    return respond({ applicationId: saved.id, email, fullName: app.fullName, plan: app.plan, planPrice: Number(app.planPrice), status: 'pending' }, 201);
  } catch (error) {
    console.error('Member registration failed:', error instanceof Error ? error.message : 'unknown');
    return respond({ error: 'Registration could not be completed. Please try again.' }, 500);
  }
});
