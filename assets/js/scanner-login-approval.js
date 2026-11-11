// Scanner handoff approval is independent of website MFA and device trust.
window.waitForScannerLoginApproval = async client => {
    const request = () => client.rpc('request_scanner_login_approval', {
        p_device_label: String(navigator.userAgent || 'Attendance scanner').slice(0, 180)
    });
    const first = await request();
    if (first.error) throw new Error('Could not request scanner access. Your other scanner stays signed in. Try again.');
    if (['ready', 'approved'].includes(first.data?.status)) return;
    if (first.data?.status !== 'pending') throw new Error('Scanner sign-in was denied, cancelled, or expired. Your other scanner stays signed in.');
    await new Promise((resolve, reject) => {
        const dialog = document.createElement('dialog');
        dialog.className = 'admin-mfa-dialog';
        dialog.setAttribute('aria-label', 'Scanner sign-in approval');
        dialog.innerHTML = '<h2>Waiting for your other scanner</h2><p>Keep your first phone open and choose Approve or Deny there. It stays signed in until you approve and this phone completes sign-in.</p><p role="status" aria-live="polite">Waiting for approval…</p><button type="button" class="btn-sm">Cancel sign-in</button>';
        document.body.append(dialog);
        let done = false, busy = false;
        const expires = Date.parse(first.data.expires_at);
        const status = dialog.querySelector('[role="status"]');
        function finish(error) {
            if (done) return;
            done = true; clearInterval(timer); dialog.close(); dialog.remove();
            error ? reject(error) : resolve();
        }
        async function cancel() {
            try {
                const { error } = await client.rpc('cancel_scanner_login_approval');
                if (error) throw error;
                finish(new Error('Scanner sign-in cancelled. Your other scanner stays signed in.'));
            } catch { status.textContent = 'Could not cancel the request. Check your connection and try again.'; }
        }
        dialog.querySelector('button').onclick = cancel;
        dialog.addEventListener('cancel', event => { event.preventDefault(); cancel(); });
        const timer = setInterval(async () => {
            if (done || busy) return;
            busy = true;
            try {
                if (Number.isFinite(expires) && Date.now() >= expires) { finish(new Error('Scanner approval expired. Your other scanner stays signed in. Sign in again.')); return; }
                const { data, error } = await request();
                if (done) return;
                if (error) { status.textContent = 'Connection interrupted. Your other scanner stays signed in. Retrying…'; return; }
                if (['ready', 'approved'].includes(data?.status)) finish();
                else if (data?.status !== 'pending') finish(new Error('Scanner sign-in was denied, cancelled, or expired. Your other scanner stays signed in.'));
            } catch { if (!done) status.textContent = 'Connection interrupted. Waiting to confirm approval…'; }
            finally { busy = false; }
        }, 3000);
        dialog.showModal();
    });
};

window.stopScannerApprovalNotifications = client => client?.__stopScannerApprovals?.();
window.startScannerApprovalNotifications = client => {
    if (!client || client.__stopScannerApprovals) return;
    let stopped = false, busy = false, panel;
    async function refresh() {
        if (stopped || busy || document.hidden || navigator.onLine === false) return;
        busy = true;
        try {
            const { data, error } = await client.rpc('list_scanner_login_approvals');
            if (stopped || error) return;
            if (!data?.length) { panel?.remove(); panel = null; return; }
            const request = data[0];
            if (panel?.dataset.requestId === request.id) return;
            panel?.remove();
            panel = document.createElement('section'); panel.className = 'admin-login-notification';
            panel.dataset.requestId = request.id;
            panel.setAttribute('role', 'region'); panel.setAttribute('aria-label', 'Another scanner wants to sign in'); panel.setAttribute('aria-live', 'polite');
            panel.innerHTML = '<h3>Allow another scanner?</h3><p>Another phone is signing in with your account. Approving lets it replace this scanner when its sign-in completes.</p><p class="approval-device"></p><small>Approve only a sign-in you started. Browser details are reported by the requesting phone.</small><p class="approval-result" role="status" aria-live="polite"></p><div class="modal-actions"><button type="button" class="btn-danger" data-decision="deny">Deny</button><button type="button" class="btn-primary" data-decision="approve">Approve</button></div>';
            panel.querySelector('.approval-device').textContent = request.device_label;
            for (const button of panel.querySelectorAll('[data-decision]')) {
                button.onclick = async () => {
                    const current = panel;
                    const buttons = current.querySelectorAll('button');
                    buttons.forEach(item => { item.disabled = true; });
                    try {
                        const { error } = await client.rpc('decide_scanner_login_approval', { p_request_id: request.id, p_approve: button.dataset.decision === 'approve' });
                        if (error) throw error;
                        current.remove(); if (panel === current) panel = null;
                    } catch {
                        current.querySelector('.approval-result').textContent = 'Could not save the decision. Your scanner stays signed in. Try again.';
                        buttons.forEach(item => { item.disabled = false; });
                    }
                };
            }
            document.body.append(panel);
        } finally { busy = false; }
    }
    const wake = () => refresh().catch(() => {});
    const timer = setInterval(wake, 3000);
    window.addEventListener('focus', wake); window.addEventListener('online', wake);
    document.addEventListener('visibilitychange', wake);
    client.__stopScannerApprovals = () => {
        stopped = true; clearInterval(timer); panel?.remove();
        window.removeEventListener('focus', wake); window.removeEventListener('online', wake);
        document.removeEventListener('visibilitychange', wake); client.__stopScannerApprovals = null;
    };
    wake();
};
