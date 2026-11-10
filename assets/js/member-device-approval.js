// Member browser keys stay in IndexedDB; the server stores only public keys.
window.readMemberDeviceKey = async () => {
    if (!window.isSecureContext || !window.indexedDB || !crypto.subtle) throw new Error('Member device approval requires HTTPS and browser storage.');
    const db = await new Promise((resolve, reject) => {
        const request = indexedDB.open('irongrind-member-device', 1);
        request.onupgradeneeded = () => request.result.createObjectStore('keys');
        request.onsuccess = () => resolve(request.result);
        request.onerror = () => reject(new Error('Browser device storage is unavailable.'));
    });
    try {
        const existing = await new Promise((resolve, reject) => {
            const request = db.transaction('keys', 'readonly').objectStore('keys').get('device');
            request.onsuccess = () => resolve(request.result);
            request.onerror = () => reject(request.error);
        });
        if (existing?.privateKey && existing.publicKey && existing.deviceId) return existing;
        const pair = await crypto.subtle.generateKey({ name: 'ECDSA', namedCurve: 'P-256' }, false, ['sign', 'verify']);
        const value = { deviceId: crypto.randomUUID(), privateKey: pair.privateKey, publicKey: await crypto.subtle.exportKey('jwk', pair.publicKey) };
        await new Promise((resolve, reject) => {
            const transaction = db.transaction('keys', 'readwrite');
            transaction.objectStore('keys').add(value, 'device');
            transaction.oncomplete = () => resolve();
            transaction.onerror = transaction.onabort = () => reject(transaction.error);
        });
        return value;
    } catch (error) {
        if (error?.name === 'ConstraintError') return window.readMemberDeviceKey();
        throw new Error('Could not save this browser’s device key. Allow site storage and try again.');
    } finally { db.close(); }
};

window.requireMemberDeviceApproval = async client => {
    const device = await window.readMemberDeviceKey();
    const call = async body => {
        const { data, error } = await client.functions.invoke('member-device-trust', { body });
        if (error) {
            let message;
            try { message = (await error.context?.json?.())?.error; } catch {}
            throw new Error(message || 'Member device approval is unavailable. Check your connection and try again.');
        }
        if (!data) throw new Error('Member device verification returned no result.');
        return data;
    };
    const challenge = await call({ action: 'challenge', deviceId: device.deviceId, publicKey: device.publicKey });
    if (challenge.skip === true) return;
    if (typeof challenge.message !== 'string') throw new Error('Member device challenge is unavailable.');
    const signature = btoa(String.fromCharCode(...new Uint8Array(await crypto.subtle.sign(
        { name: 'ECDSA', hash: 'SHA-256' }, device.privateKey, new TextEncoder().encode(challenge.message)
    ))));
    const complete = () => call({ action: 'complete', signature, label: String(navigator.userAgent || 'Browser').slice(0, 180) });
    const result = await complete();
    if (result.status === 'authorized') return;
    if (result.status !== 'pending') throw new Error(result.status === 'denied'
        ? 'The device request was denied. Sign in again from your previous device or contact the gym.'
        : 'The approval request expired. Sign in again and retry.');
    await new Promise((resolve, reject) => {
        const dialog = document.createElement('dialog');
        dialog.className = 'admin-mfa-dialog member-device-wait';
        dialog.setAttribute('aria-label', 'Member device approval');
        dialog.innerHTML = `<h2>Approve this device?</h2><p>Open your member dashboard on your currently registered device and approve this sign-in request.</p><p role="status" aria-live="polite">Waiting for approval…</p><div class="modal-actions"><button type="button" class="btn-sm" data-cancel>Cancel sign-in</button></div><small>This request expires in two minutes. No authenticator code is needed.</small>`;
        document.body.append(dialog);
        let done = false, busy = false;
        const status = dialog.querySelector('[role="status"]');
        const expires = Date.parse(result.expires_at);
        const timer = setInterval(async () => {
            if (done || busy) return;
            busy = true;
            try {
                if (Number.isFinite(expires) && Date.now() >= expires) throw new Error('Approval request expired. Sign in again and retry.');
                const state = await call({ action: 'status' });
                if (state.status === 'approved') {
                    const finished = await complete();
                    if (finished.status === 'authorized') finish();
                    else if (finished.status !== 'pending') throw new Error('The device request could not be completed. Sign in again.');
                } else if (state.status === 'denied') throw new Error('The device request was denied. Sign in again from your previous device or contact the gym.');
                else if (state.status === 'expired' || state.status === 'consumed') throw new Error('The approval request expired. Sign in again and retry.');
                else status.textContent = 'Waiting for approval from your currently registered device…';
            } catch (error) { finish(error); }
            finally { busy = false; }
        }, 3000);
        function finish(error) {
            if (done) return;
            done = true; clearInterval(timer); dialog.close(); dialog.remove();
            error ? reject(error) : resolve();
        }
        dialog.querySelector('[data-cancel]').onclick = () => finish(new Error('Sign-in cancelled.'));
        dialog.addEventListener('cancel', event => { event.preventDefault(); finish(new Error('Sign-in cancelled.')); });
        dialog.showModal();
    });
};

window.stopMemberDeviceApprovalNotifications = client => client?.__stopMemberDeviceApprovalNotifications?.();
window.startMemberDeviceApprovalNotifications = client => {
    if (!client || client.__stopMemberDeviceApprovalNotifications) return;
    let stopped = false, busy = false, panel;
    async function refresh() {
        if (stopped || busy || document.hidden || navigator.onLine === false) return;
        busy = true;
        try {
            const { data, error } = await client.rpc('list_member_device_approvals');
            if (stopped || error) return;
            if (!data?.length) { panel?.remove(); panel = null; return; }
            const request = data[0];
            if (panel?.dataset.requestId === request.id) return;
            panel?.remove();
            panel = document.createElement('section');
            panel.className = 'admin-login-notification member-device-notification';
            panel.dataset.requestId = request.id;
            panel.setAttribute('role', 'region');
            panel.setAttribute('aria-label', 'Member device approval request');
            panel.setAttribute('aria-live', 'polite');
            panel.innerHTML = `<h3>Is this you?</h3><p>A new browser is requesting access to your member account.</p><p class="approval-device"></p><p class="approval-time"></p><small>Approve only if you started this sign-in. Browser details are reported by that browser.</small><p class="approval-result" role="status" aria-live="polite"></p><div class="modal-actions"><button type="button" class="btn-danger" data-decision="false">Deny</button><button type="button" class="btn-primary" data-decision="true">Approve device</button></div>`;
            panel.querySelector('.approval-device').textContent = request.device_label;
            panel.querySelector('.approval-time').textContent = new Date(request.requested_at).toLocaleString('en-PH', { timeZone: 'Asia/Manila' });
            for (const button of panel.querySelectorAll('[data-decision]')) button.onclick = async () => {
                const current = panel, controls = current.querySelectorAll('button');
                controls.forEach(item => { item.disabled = true; });
                try {
                    const { error: decisionError } = await client.rpc('decide_member_device_approval', {
                        p_request_id: request.id, p_approve: button.dataset.decision === 'true'
                    });
                    if (decisionError) throw decisionError;
                    current.remove(); if (panel === current) panel = null;
                } catch {
                    current.querySelector('.approval-result').textContent = 'Could not save your decision. The request may have expired. Try refreshing.';
                    controls.forEach(item => { item.disabled = false; });
                }
            };
            document.body.append(panel);
        } finally { busy = false; }
    }
    const timer = setInterval(() => refresh().catch(() => {}), 5000);
    const focus = () => refresh().catch(() => {});
    window.addEventListener('focus', focus);
    client.__stopMemberDeviceApprovalNotifications = () => {
        stopped = true; clearInterval(timer); window.removeEventListener('focus', focus);
        panel?.remove(); client.__stopMemberDeviceApprovalNotifications = null;
    };
    refresh().catch(() => {});
};
