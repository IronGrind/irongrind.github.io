let managedStaffAccounts = [];

async function invokeStaffManager(body) {
    const { data, error } = await window.ironGrindSupabase.functions.invoke('admin-create-staff', { body });
    if (error) {
        const detail = await error.context?.json?.().catch(() => null);
        throw new Error(detail?.error || error.message);
    }
    if (data?.error) throw new Error(data.error);
    return data;
}

window.loadStaffAccounts = async function loadStaffAccounts() {
    const list = document.getElementById('staffAccountsList');
    const status = document.getElementById('staffAccountsStatus');
    if (!list || !status) return;
    status.textContent = 'Loading staff accounts…';
    try {
        const data = await invokeStaffManager({ action: 'list' });
        managedStaffAccounts = Array.isArray(data?.staff) ? data.staff : [];
        status.textContent = `${managedStaffAccounts.length} staff account${managedStaffAccounts.length === 1 ? '' : 's'}.`;
        list.innerHTML = managedStaffAccounts.length ? managedStaffAccounts.map(staff => `<article class="staff-account-card"><div><div class="staff-account-name">${escapeHTML(staff.full_name || 'Unnamed staff')}</div><div class="staff-account-meta"><span>@${escapeHTML(staff.username || 'no-username')}</span><span class="staff-status ${staff.is_active ? 'active' : 'inactive'}">${staff.is_active ? 'Active' : 'Inactive'}</span><span>Created ${escapeHTML(new Date(staff.created_at).toLocaleDateString('en-PH'))}</span></div></div><div class="staff-account-actions"><button class="btn-sm" type="button" onclick="viewStaffAccount('${staff.id}')"><i class="fas fa-eye"></i> Details</button><button class="btn-sm" type="button" onclick="setStaffAccountActive('${staff.id}', ${!staff.is_active})">${staff.is_active ? 'Deactivate' : 'Activate'}</button></div></article>`).join('') : '<div class="empty-state">No staff accounts have been created.</div>';
    } catch (error) { status.textContent = error.message || 'Could not load staff accounts.'; list.innerHTML = ''; }
};

window.viewStaffAccount = function viewStaffAccount(id) {
    const staff = managedStaffAccounts.find(account => account.id === id);
    if (!staff) return;
    openModal(`<h3><i class="fas fa-id-badge"></i> Staff Account Details</h3><div class="member-detail-grid" style="margin-top:16px;"><div><span>Full name</span><strong>${escapeHTML(staff.full_name || 'Not recorded')}</strong></div><div><span>Username</span><strong>@${escapeHTML(staff.username || 'Not recorded')}</strong></div><div><span>Access</span><strong>Attendance only</strong></div><div><span>Status</span><strong>${staff.is_active ? 'Active' : 'Inactive'}</strong></div><div><span>Created</span><strong>${escapeHTML(new Date(staff.created_at).toLocaleString('en-PH'))}</strong></div></div><div class="modal-actions"><button class="btn-sm" type="button" onclick="closeModal()">Close</button></div>`);
};

window.setStaffAccountActive = async function setStaffAccountActive(id, isActive) {
    const status = document.getElementById('staffAccountsStatus');
    status.textContent = `${isActive ? 'Activating' : 'Deactivating'} account…`;
    try { await invokeStaffManager({ action: 'set_active', id, isActive }); await loadStaffAccounts(); }
    catch (error) { status.textContent = error.message || 'Could not update the staff account.'; }
};

document.getElementById('staffAccountForm').addEventListener('submit', async event => {
    event.preventDefault();
    const button = event.target.querySelector('button');
    const status = document.getElementById('staffAccountStatus');
    button.disabled = true;
    status.textContent = 'Creating account…';
    try {
        const { data, error } = await window.ironGrindSupabase.functions.invoke('admin-create-staff', { body: {
            fullName: document.getElementById('staffName').value.trim(),
            username: document.getElementById('staffUsername').value.trim(),
            password: document.getElementById('staffPassword').value
        } });
        if (error) {
            const detail = await error.context?.json?.().catch(() => null);
            throw new Error(detail?.error || error.message);
        }
        if (data?.error) throw new Error(data.error);
        event.target.reset();
        status.textContent = 'Staff account created. They can sign in with their username and password.';
        await loadStaffAccounts();
    } catch (error) { status.textContent = error.message || 'Could not create staff account.'; }
    finally { button.disabled = false; }
});
