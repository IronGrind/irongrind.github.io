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
    } catch (error) { status.textContent = error.message || 'Could not create staff account.'; }
    finally { button.disabled = false; }
});
