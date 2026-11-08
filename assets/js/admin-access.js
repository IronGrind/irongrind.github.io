// Check the authenticated database identity, rather than the browser's UI session.
window.requireVerifiedAdmin = async function (client = window.ironGrindSupabase) {
    if (!client) throw new Error('The login service is unavailable. Reload and sign in again.');
    const { data: { user } = {}, error } = await client.auth.getUser();
    if (error || !user) throw new Error('Your admin login has expired. Sign in again with an admin account. The pairing password cannot sign you in.');
    const { data: profile, error: profileError } = await client.from('profiles')
        .select('role,username,full_name,is_active').eq('id', user.id).maybeSingle();
    if (profileError) throw new Error(`Could not verify your account: ${profileError.message}`);
    if (profile?.role !== 'admin') {
        throw new Error(`Your current account has ${profile?.role || 'no assigned'} access. Sign in with an admin account to create a pairing QR. Staff can scan attendance on an already paired phone.`);
    }
    if (profile.is_active !== true) throw new Error('This admin account is inactive. Contact the gym administrator.');
    return { user, profile };
};

window.clearIronGrindUiSession = function () {
    localStorage.removeItem('irongrind_session');
    sessionStorage.removeItem('irongrind_session');
};

window.redirectExpiredAdminSession = async function (client = window.ironGrindSupabase) {
    window.clearIronGrindUiSession();
    try { await client?.auth.signOut({ scope: 'local' }); } catch {}
    window.location.replace('index.html?role=admin&auth=expired');
};
