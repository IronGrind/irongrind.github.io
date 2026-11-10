// Approval grants stay bound to server sessions. Browser labels are reported, not verified identities.
window.waitForAdminDeviceApproval = async (client, scope) => {
    const request = () => client.rpc('request_admin_login_approval', {
        p_scope: scope, p_device_label: String(navigator.userAgent || 'Browser').slice(0, 180)
    });
    const first = await request();
    if (first.error) throw new Error('Could not request device approval. Check your connection or contact the project owner.');
    if (first.data?.status === 'mfa_required') return false;
    if (first.data?.status === 'approved') return true;
    if (first.data?.status !== 'pending') throw new Error('This sign-in request was denied, cancelled, or expired. Sign in again.');
    return new Promise((resolve, reject) => {
        const dialog = document.createElement('dialog'); dialog.className = 'admin-mfa-dialog';
        dialog.setAttribute('aria-label', 'Administrator device approval');
        dialog.innerHTML = `<h2>Approve this device transfer</h2><p>Approve from your current device, then verify your authenticator here.</p><p role="status" aria-live="polite">Waiting for approval…</p><div class="modal-actions"><button type="button" data-action="cancel" class="btn-sm">Cancel sign-in</button><button type="button" data-action="mfa" class="btn-primary">Authenticator recovery</button></div><small>Recovery requires the old device to be signed out or inactive for at least two minutes.</small>`;
        document.body.append(dialog);
        let done = false, busy = false, timer;
        const expires = Date.parse(first.data.expires_at);
        const status = dialog.querySelector('[role="status"]');
        function finish(error, approved = false) {
            if (done) return; done = true; clearInterval(timer); dialog.close(); dialog.remove();
            error ? reject(error) : resolve(approved);
        }
        async function leave(useMfa) {
            try {
                const { error } = await client.rpc('cancel_admin_login_approval', { p_scope: scope });
                if (error) throw error;
                finish(useMfa ? null : new Error('Sign-in cancelled.'), false);
            } catch { status.textContent = 'Could not cancel the pending request. Check your connection and try again.'; }
        }
        dialog.querySelector('[data-action="cancel"]').onclick = () => leave(false);
        dialog.querySelector('[data-action="mfa"]').onclick = () => leave(true);
        dialog.addEventListener('cancel', event => { event.preventDefault(); leave(false); });
        timer = setInterval(async () => {
            if (done || busy) return; busy = true;
            try {
                if (Number.isFinite(expires) && Date.now() >= expires) { finish(new Error('Approval request expired. Sign in again or use an authenticator.')); return; }
                const { data, error } = await request();
                if (done) return;
                if (error) { status.textContent = 'Connection interrupted. Waiting to confirm approval…'; return; }
                if (data?.status === 'approved') finish(null, true);
                else if (data?.status !== 'pending') finish(new Error('Sign-in was denied, cancelled, or expired.'));
            } catch { if (!done) status.textContent = 'Connection interrupted. Waiting to confirm approval…'; }
            finally { busy = false; }
        }, 3000);
        dialog.showModal();
    });
};

window.stopAdminApprovalNotifications = client => client?.__stopApprovalNotifications?.();
window.startAdminApprovalNotifications = client => {
    if (!client || client.__stopApprovalNotifications) return;
    let stopped = false, busy = false, panel;
    async function refresh() {
        if (stopped || busy || document.hidden || navigator.onLine === false) return;
        busy = true;
        try {
            const { data, error } = await client.rpc('list_admin_login_approvals');
            if (stopped || error) return;
            if (!data?.length) { panel?.remove(); panel = null; return; }
            if (panel?.dataset.requestId === data[0].id) return;
            panel?.remove();
            const request = data[0];
            panel = document.createElement('section'); panel.className = 'admin-login-notification';
            panel.dataset.requestId = request.id; panel.setAttribute('role', 'region'); panel.setAttribute('aria-label', 'Sign-in approval request'); panel.setAttribute('aria-live', 'polite');
            panel.innerHTML = `<h3>Is this you?</h3><p>Another browser is requesting administrator access.</p><p class="approval-device"></p><p class="approval-time"></p><small>Approve only a sign-in you started. Browser details are reported by the requesting device.</small><p class="approval-result" role="status" aria-live="polite"></p><div class="modal-actions"><button type="button" class="btn-danger" data-decision="deny">Deny</button><button type="button" class="btn-primary" data-decision="approve">Approve sign-in</button></div>`;
            panel.querySelector('.approval-device').textContent = request.device_label;
            panel.querySelector('.approval-time').textContent = `${request.session_scope === 'attendance' ? 'Attendance scanner' : 'Dashboard'} · ${new Date(request.requested_at).toLocaleString('en-PH', { timeZone: 'Asia/Manila' })}`;
            for (const button of panel.querySelectorAll('[data-decision]')) {
                button.onclick = async () => {
                    const current = panel; const controls = current.querySelectorAll('button');
                    controls.forEach(item => { item.disabled = true; });
                    try {
                        const { error } = await client.rpc('decide_admin_login_approval', { p_request_id: request.id, p_approve: button.dataset.decision === 'approve' });
                        if (error) throw error;
                        current.remove(); if (panel === current) panel = null;
                    } catch {
                        current.querySelector('.approval-result').textContent = 'Could not save the decision. The request may have expired. Check your connection and try again.';
                        controls.forEach(item => { item.disabled = false; });
                    }
                };
            }
            document.body.append(panel);
        } finally { busy = false; }
    }
    const timer = setInterval(() => refresh().catch(() => {}), 5000);
    const focus = () => refresh().catch(() => {});
    window.addEventListener('focus', focus);
    client.__stopApprovalNotifications = () => { stopped = true; clearInterval(timer); window.removeEventListener('focus', focus); panel?.remove(); client.__stopApprovalNotifications = null; };
    refresh().catch(() => {});
};
if (/(?:^|\/)admin\.html$/.test(window.location.pathname)) window.startAdminApprovalNotifications(window.ironGrindSupabase);
