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
        dialog.innerHTML = '<h2>Another scanner session is on record</h2><p>If that scanner is open, choose Approve or Deny on it. If nobody is using another scanner, tap Recover inactive session now. The server checks recent activity and will keep a recently active scanner protected.</p><p role="status" aria-live="polite">Waiting for approval or inactive-session recovery…</p><button type="button" class="btn-sm" data-action="cancel">Cancel sign-in</button><button type="button" class="btn-primary" data-action="recover">Recover inactive session</button>';
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
        dialog.querySelector('[data-action="cancel"]').onclick = cancel;
        dialog.querySelector('[data-action="recover"]').onclick = async () => {
            if (done || busy) return;
            busy = true;
            try {
                const { error } = await client.rpc('recover_inactive_attendance_session');
                if (error) {
                    status.textContent = error.message === 'SCANNER_STILL_ACTIVE'
                        ? 'The other scanner was active within the last two minutes. Keep it open to approve, or wait until it is inactive for two minutes.'
                        : 'Could not recover the scanner session. Cancel and sign in again, or check your connection.';
                    return;
                }
                finish();
            } catch { status.textContent = 'Could not confirm recovery. Check the connection and try again.'; }
            finally { busy = false; }
        };
        dialog.addEventListener('cancel', event => { event.preventDefault(); cancel(); });
        const timer = setInterval(async () => {
            if (done || busy) return;
            busy = true;
            try {
                if (Number.isFinite(expires) && Date.now() >= expires) {
                    status.textContent = 'Approval expired. Cancel and sign in again, or choose Recover inactive session if no other scanner is open.';
                    return;
                }
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
    function report(message) {
        const target = document.getElementById('phoneApprovalStatus');
        if (target) target.textContent = message;
    }
    async function refresh() {
        if (stopped || busy || document.hidden || navigator.onLine === false) return;
        busy = true;
        try {
            const { data, error } = await client.rpc('list_scanner_login_approvals');
            if (stopped) return;
            if (error) {
                const code = /^[A-Z0-9_]{1,30}$/.test(error.code || '') ? ` (${error.code})` : '';
                report(error.message === 'Active scanner session required'
                    ? 'This scanner session is no longer active. Use Change operator, then sign in again.'
                    : `Sign-in request checks failed${code}. Check your connection, then tap Check sign-in requests.`);
                return;
            }
            report('Listening for sign-in requests while this scanner is open.');
            if (!data?.length) { panel?.close(); panel?.remove(); panel = null; return; }
            const request = data[0];
            if (panel?.dataset.requestId === request.id) return;
            panel?.close(); panel?.remove();
            panel = document.createElement('dialog'); panel.className = 'admin-mfa-dialog';
            panel.dataset.requestId = request.id;
            panel.setAttribute('aria-label', 'Another scanner wants to sign in'); panel.setAttribute('aria-live', 'polite');
            panel.addEventListener('cancel', event => event.preventDefault());
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
                        current.close(); current.remove(); if (panel === current) panel = null;
                    } catch {
                        current.querySelector('.approval-result').textContent = 'Could not save the decision. Your scanner stays signed in. Try again.';
                        buttons.forEach(item => { item.disabled = false; });
                    }
                };
            }
            document.body.append(panel);
            panel.showModal();
        } catch {
            report('Sign-in request checks failed. Check your connection, then tap Check sign-in requests.');
        } finally { busy = false; }
    }
    const wake = () => refresh().catch(() => {});
    const timer = setInterval(wake, 3000);
    client.__refreshScannerApprovals = wake;
    window.addEventListener('focus', wake); window.addEventListener('online', wake);
    document.addEventListener('visibilitychange', wake);
    client.__stopScannerApprovals = () => {
        stopped = true; clearInterval(timer); panel?.close(); panel?.remove();
        window.removeEventListener('focus', wake); window.removeEventListener('online', wake);
        document.removeEventListener('visibilitychange', wake); client.__stopScannerApprovals = null;
        client.__refreshScannerApprovals = null;
    };
    wake();
};
