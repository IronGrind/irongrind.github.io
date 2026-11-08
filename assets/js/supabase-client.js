// Public browser configuration. The publishable key is safe to expose when
// database tables are protected by Row Level Security policies.
const IRON_GRIND_SUPABASE_URL = 'https://nttsrdassmzvtaamyogi.supabase.co';
const IRON_GRIND_SUPABASE_PUBLISHABLE_KEY = 'sb_publishable_aJUpD0v8XUengFdItDJGQw_rZK4anzm';

// Authentication lasts for the current browser session. The login form's
// Remember me option stores only the login identifier, never this auth token.
const IRON_GRIND_AUTH_STORAGE_KEY = 'sb-nttsrdassmzvtaamyogi-auth-token';
const IRON_GRIND_REMEMBERED_LOGIN_KEY = 'ig_remembered_login_identifier';

// Remove the auth token and UI marker left by the previous Remember me
// implementation, which stored a persistent session regardless of the choice.
if (!document.body?.classList.contains('register-body')) {
    localStorage.removeItem(IRON_GRIND_AUTH_STORAGE_KEY);
    localStorage.removeItem('ig_remember_login');
    localStorage.removeItem('irongrind_session');
}

// Registration must not replace an administrator's session in another tab.
// It uses its own temporary session for the application submission.
const IRON_GRIND_SUPABASE_OPTIONS = document.body?.classList.contains('register-body')
    ? { auth: { storageKey: 'irongrind-registration-auth', persistSession: false, detectSessionInUrl: true } }
    : { auth: { storageKey: IRON_GRIND_AUTH_STORAGE_KEY, storage: sessionStorage, persistSession: true, detectSessionInUrl: true } };

window.ironGrindSupabase = window.supabase.createClient(
    IRON_GRIND_SUPABASE_URL,
    IRON_GRIND_SUPABASE_PUBLISHABLE_KEY,
    IRON_GRIND_SUPABASE_OPTIONS
);

// A guard verifies the server-issued session; page reloads never reclaim a session.
window.monitorAccountSession = (client, onReplaced) => {
    if (client.__accountSessionMonitor) return;
    client.__accountSessionMonitor = true;
    let busy = false;
    let stopping = false;
    let hadSession = false;
    async function check() {
        if (busy || stopping || document.hidden || navigator.onLine === false) return;
        busy = true;
        try {
            const { data: { session } } = await client.auth.getSession();
            if (!session) {
                if (hadSession) { stopping = true; client.__accountSessionMonitor = false; await onReplaced('expired'); }
                return;
            }
            hadSession = true;
            const token = session.access_token;
            const { data, error } = await client.rpc('current_account_session_is_active');
            const { data: latest } = await client.auth.getSession();
            // Ignore an in-flight check belonging to credentials that have changed.
            if (latest.session?.access_token !== token) return;
            if (data === false || error?.code === 'PT401' || error?.message === 'ACCOUNT_SESSION_REPLACED') {
                stopping = true;
                client.__accountSessionMonitor = false;
                await client.auth.signOut({ scope: 'local' });
                await onReplaced();
            }
        } catch (error) {
            console.warn('Could not check the account session:', error);
        } finally { busy = false; }
    }
    setInterval(check, 5000);
    window.addEventListener('focus', check);
    window.addEventListener('online', check);
    document.addEventListener('visibilitychange', check);
    client.auth.onAuthStateChange(() => { setTimeout(check, 0); });
    check();
};
if (/(?:^|\/)(?:admin|customer|staff)\.html$/.test(window.location.pathname)) {
    window.monitorAccountSession(window.ironGrindSupabase, async reason => {
        localStorage.removeItem('irongrind_session');
        sessionStorage.removeItem('irongrind_session');
        window.location.replace(`index.html?auth=${reason === 'expired' ? 'expired' : 'replaced'}`);
    });
}
