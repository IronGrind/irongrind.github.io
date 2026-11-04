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
    if (!data?.length) {
        const row = rows.insertRow();
        const cell = row.insertCell();
        cell.colSpan = 3;
        cell.textContent = 'No attendance records yet.';
    }
    for (const visit of data || []) {
        const row = document.createElement('tr');
        for (const [index, value] of [visit.member_name, visit.time_in, visit.time_out].entries()) {
            const cell = document.createElement('td');
            cell.textContent = index === 0 ? value || 'Unknown member' : value
                ? new Date(value).toLocaleString('en-PH', { timeZone: 'Asia/Manila', month: 'short', day: 'numeric', year: 'numeric', hour: 'numeric', minute: '2-digit' })
                : 'Still checked in';
            if (index === 2 && !value) cell.classList.add('staff-visit-open');
            row.append(cell);
        }
        rows.append(row);
    }
}
async function recordStaffAttendance(value) {
    if (staffBusy || !staffUser) return;
    staffBusy = true;
    try {
        const { data, error } = await staffClient.rpc('record_attendance_scan', {
            p_identifier: value.trim(), p_request_id: crypto.randomUUID()
        });
        if (error) throw error;
        staffStatus.textContent = data.member_name + (data.action === 'duplicate' ? ' was already scanned just now.' : data.action === 'check_out' ? ' checked out.' : ' checked in.');
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
