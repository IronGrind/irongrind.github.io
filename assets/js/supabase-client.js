// Public browser configuration. The publishable key is safe to expose when
// database tables are protected by Row Level Security policies.
const IRON_GRIND_SUPABASE_URL = 'https://nttsrdassmzvtaamyogi.supabase.co';
const IRON_GRIND_SUPABASE_PUBLISHABLE_KEY = 'sb_publishable_aJUpD0v8XUengFdItDJGQw_rZK4anzm';

// Signing up a member must not replace an administrator's session in another
// tab. Registration needs its own temporary session to submit the application;
// email-confirmation callbacks can still establish it from the redirect URL.
const IRON_GRIND_SUPABASE_OPTIONS = document.body?.classList.contains('register-body')
    ? { auth: { storageKey: 'irongrind-registration-auth', persistSession: false, detectSessionInUrl: true } }
    : {};

window.ironGrindSupabase = window.supabase.createClient(
    IRON_GRIND_SUPABASE_URL,
    IRON_GRIND_SUPABASE_PUBLISHABLE_KEY,
    IRON_GRIND_SUPABASE_OPTIONS
);
