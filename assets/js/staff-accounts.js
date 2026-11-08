const staffAccountsClient = window.ironGrindSupabase;
const staffAccountForm = document.getElementById('staffAccountForm');

function setStaffAccountsMessage(message, isError = false) {
    const status = document.getElementById('staffAccountsStatus');
    if (!status) return;
    status.textContent = message;
    status.classList.toggle('error', isError);
}

async function callStaffAccountService(body) {
    const { data, error } = await staffAccountsClient.functions.invoke('admin-create-staff', { body });
    if (error) {
        const detail = await error.context?.json?.().catch(() => null);
        throw new Error(detail?.error || error.message || 'Staff account request failed.');
    }
    if (data?.error) throw new Error(data.error);
    return data;
}

async function loadStaffAccounts() {
    const list = document.getElementById('staffAccountsList');
    if (!list) return;
    list.setAttribute('aria-busy', 'true');
    setStaffAccountsMessage('Loading staff accounts…');
    try {
        const data = await callStaffAccountService({ action: 'list' });
        list.replaceChildren();
        const staff = Array.isArray(data?.staff) ? data.staff : [];
        if (!staff.length) {
            setStaffAccountsMessage('No staff accounts yet.');
            return;
        }
        staff.forEach(account => {
            const card = document.createElement('article');
            card.className = 'staff-account-card';
            const identity = document.createElement('div');
            identity.className = 'staff-account-identity';
            const name = document.createElement('strong');
            name.className = 'staff-account-name';
            name.textContent = account.full_name || 'Staff member';
            const meta = document.createElement('small');
            meta.className = 'staff-account-meta';
            meta.textContent = `@${account.username || '—'} · ${account.is_active ? 'Active' : 'Inactive'}`;
            identity.append(name, meta);

            const actions = document.createElement('div');
            actions.className = 'staff-account-actions';
            const details = document.createElement('button');
            details.type = 'button';
            details.className = 'btn-sm';
            details.textContent = 'Details';
            details.setAttribute('aria-expanded', 'false');
            const detailsPanel = document.createElement('div');
            detailsPanel.className = 'staff-account-details';
            detailsPanel.hidden = true;
            detailsPanel.textContent = [
                account.email,
                account.phone_number,
                account.gender,
                account.created_at ? `Created ${new Date(account.created_at).toLocaleDateString()}` : '',
            ].filter(Boolean).join(' · ');
            details.addEventListener('click', () => {
                detailsPanel.hidden = !detailsPanel.hidden;
                details.setAttribute('aria-expanded', String(!detailsPanel.hidden));
            });

            const toggle = document.createElement('button');
            toggle.type = 'button';
            toggle.className = account.is_active ? 'btn-sm btn-danger' : 'btn-sm';
            toggle.textContent = account.is_active ? 'Deactivate' : 'Activate';
            toggle.addEventListener('click', async () => {
                toggle.disabled = true;
                try {
                    await callStaffAccountService({ action: 'set_active', id: account.id, isActive: !account.is_active });
                    await loadStaffAccounts();
                } catch (error) {
                    setStaffAccountsMessage(error.message || 'Could not update this account.', true);
                    toggle.disabled = false;
                }
            });
            actions.append(details, toggle);
            card.append(identity, actions, detailsPanel);
            list.append(card);
        });
        setStaffAccountsMessage(`${staff.length} staff account${staff.length === 1 ? '' : 's'}.`);
    } catch (error) {
        list.replaceChildren();
        setStaffAccountsMessage(error.message || 'Could not load staff accounts.', true);
    } finally {
        list.removeAttribute('aria-busy');
    }
}

staffAccountForm?.addEventListener('submit', async event => {
    event.preventDefault();
    if (!staffAccountForm.reportValidity()) return;
    if (document.getElementById('staffPassword').value !== document.getElementById('staffConfirmPassword').value) return;
    if (!newPasswordValid(document.getElementById('staffPassword').value, 12)) {
        document.getElementById('staffPassword').reportValidity();
        return;
    }
    const button = staffAccountForm.querySelector('[type="submit"]');
    const status = document.getElementById('staffAccountStatus');
    button.disabled = true;
    status.textContent = 'Creating staff account…';
    status.classList.remove('error');
    try {
        await callStaffAccountService({
            username: document.getElementById('staffUsername').value.trim(),
            fullName: document.getElementById('staffName').value.trim(),
            email: document.getElementById('staffEmail').value.trim(),
            phoneNumber: document.getElementById('staffMobile').value.replace(/\D/g, ''),
            gender: document.getElementById('staffGender').value,
            password: document.getElementById('staffPassword').value,
        });
        staffAccountForm.reset();
        status.textContent = 'Staff account created.';
        await loadStaffAccounts();
    } catch (error) {
        status.textContent = error.message || 'Could not create staff account.';
        status.classList.add('error');
    } finally {
        button.disabled = false;
    }
});
