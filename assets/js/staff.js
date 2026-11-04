const staffClient = window.ironGrindSupabase;
const staffStatus = document.getElementById('staffStatus');
let staffUser;
let staffBusy = false;
let staffScanner;
async function refreshStaffAttendance() {
    const { data, error } = await staffClient.rpc('staff_list_attendance');
    if (error) throw error;
    const rows = document.getElementById('staffAttendanceRows');
    rows.replaceChildren();
    for (const visit of data || []) {
        const row = document.createElement('tr');
        for (const value of [visit.member_name, visit.time_in, visit.time_out]) {
            const cell = document.createElement('td');
            cell.textContent = value && value !== visit.member_name ? new Date(value).toLocaleString('en-PH', { timeZone: 'Asia/Manila' }) : value || '—';
            row.append(cell);
        }
        rows.append(row);
    }
}
async function recordStaffAttendance(value) {
    if (staffBusy || !staffUser) return;
    staffBusy = true;
    try {
        const identifier = value.trim().replace(/^IRONGRIND\|/i, '');
        const { data: member, error } = await staffClient.rpc('staff_resolve_attendance_member', { p_identifier: identifier });
        if (error) throw error;
        if (!member) throw new Error('Member not found.');
        const { data: visits, error: visitError } = await staffClient.from('attendance').select('id').eq('member_id', member.id).is('time_out', null).order('time_in', { ascending: false }).limit(1);
        if (visitError) throw visitError;
        const now = new Date();
        const today = new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Manila', year: 'numeric', month: '2-digit', day: '2-digit' }).format(now);
        if (!visits.length && member.expiry_date && member.expiry_date < today) throw new Error('Membership has expired.');
        const result = visits.length
            ? await staffClient.from('attendance').update({ time_out: now.toISOString() }).eq('id', visits[0].id).is('time_out', null)
            : await staffClient.from('attendance').insert({ member_id: member.id, time_in: now.toISOString(), recorded_by: staffUser.id });
        if (result.error) throw result.error;
        staffStatus.textContent = `${member.full_name} checked ${visits.length ? 'out' : 'in'}.`;
        document.getElementById('staffIdentifier').value = '';
        await refreshStaffAttendance();
    } catch (error) { staffStatus.textContent = error.message; }
    finally { staffBusy = false; }
}
document.getElementById('staffScanForm').addEventListener('submit', event => { event.preventDefault(); recordStaffAttendance(document.getElementById('staffIdentifier').value); });
document.getElementById('refreshStaffAttendance').onclick = () => refreshStaffAttendance().catch(error => { staffStatus.textContent = error.message; });
document.getElementById('startStaffCamera').onclick = async () => {
    if (!staffUser || staffScanner) return;
    try {
        staffScanner = new Html5Qrcode('staffCamera');
        await staffScanner.start({ facingMode: 'environment' }, { fps: 10, qrbox: 250 }, async value => {
            await staffScanner.stop();
            staffScanner = null;
            await recordStaffAttendance(value);
        }, () => {});
    } catch (error) { staffScanner = null; staffStatus.textContent = `Could not open camera: ${error.message || error}`; }
};
document.getElementById('staffLogout').onclick = async () => {
    await staffClient.auth.signOut();
    localStorage.removeItem('irongrind_session'); sessionStorage.removeItem('irongrind_session');
    location.replace('index.html');
};
(async () => {
    try {
        const { data: { user }, error } = await staffClient.auth.getUser();
        if (error || !user) return location.replace('index.html');
        const { data: profile, error: profileError } = await staffClient.from('profiles').select('role,is_active,full_name').eq('id', user.id).single();
        if (profileError || profile?.role !== 'staff' || !profile.is_active) return location.replace('index.html');
        staffUser = user;
        document.getElementById('staffIdentity').textContent = profile.full_name;
        await refreshStaffAttendance();
    } catch (error) { staffStatus.textContent = error.message; }
})();
