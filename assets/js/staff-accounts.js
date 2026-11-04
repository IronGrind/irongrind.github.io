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
    const field = (label, value) => `<div class="member-detail-field"><span>${label}</span><strong>${escapeHTML(value || 'Not recorded')}</strong></div>`;
    openModal(`<h3><i class="fas fa-id-badge"></i> Staff Account Details</h3><div class="member-detail-grid staff-detail-grid">
        ${field('Full name', staff.full_name)}${field('Username', staff.username ? `@${staff.username}` : '')}
        ${field('Gmail', staff.email)}${field('Mobile number', staff.phone_number)}${field('Gender', staff.gender)}
        ${field('Access', 'Attendance only')}${field('Status', staff.is_active ? 'Active' : 'Inactive')}
        ${field('Created', staff.created_at ? new Date(staff.created_at).toLocaleString('en-PH') : '')}
    </div><div class="modal-actions"><button class="btn-sm" type="button" onclick="closeModal()">Close</button></div>`);
};

window.setStaffAccountActive = async function setStaffAccountActive(id, isActive) {
    const status = document.getElementById('staffAccountsStatus');
    status.textContent = `${isActive ? 'Activating' : 'Deactivating'} account…`;
    try { await invokeStaffManager({ action: 'set_active', id, isActive }); await loadStaffAccounts(); }
    catch (error) { status.textContent = error.message || 'Could not update the staff account.'; }
};

document.getElementById('staffMobile')?.addEventListener('input', event => {
    const input = event.currentTarget;
    const digits = input.value.replace(/\D/g, '');
    input.value = digits && !digits.startsWith('9') ? '' : digits.slice(0, 10);
});

document.getElementById('staffPassword')?.addEventListener('input', event => {
    const input = event.currentTarget;
    input.setCustomValidity(input.value && (!/[A-Za-z]/.test(input.value) || !/[0-9]/.test(input.value))
        ? 'Include at least one letter and one number.' : '');
});

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
            email: document.getElementById('staffEmail').value.trim().toLowerCase(),
            phoneNumber: document.getElementById('staffMobile').value.replace(/\D/g, ''),
            gender: document.getElementById('staffGender').value,
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
