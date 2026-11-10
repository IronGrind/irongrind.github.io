// Shared by main login and phone operator login. Protected data stays server-gated.
window.requireAdminMfa = async client => {
    const { data: required, error } = await client.rpc('admin_mfa_required');
    if (error) throw new Error('Could not check administrator security. Refresh and try again.');
    if (required !== true) return;
    const { data: assurance, error: assuranceError } = await client.auth.mfa.getAuthenticatorAssuranceLevel();
    if (assuranceError) throw assuranceError;
    if (assurance.currentLevel === 'aal2') return;
    const { data: factors, error: factorsError } = await client.auth.mfa.listFactors();
    if (factorsError) throw factorsError;
    let factor = factors.totp?.find(item => item.status === 'verified');
    let enrollment;
    if (!factor) {
        // Remove abandoned TOTP enrollments only; never remove a verified factor.
        for (const item of factors.all || []) {
            if (item.factor_type === 'totp' && item.status === 'unverified') {
                const { error } = await client.auth.mfa.unenroll({ factorId: item.id });
                if (error) throw error;
            }
        }
        const { data, error } = await client.auth.mfa.enroll({ factorType: 'totp', friendlyName: 'IronGrind Admin', issuer: 'IronGrind' });
        if (error) throw error;
        enrollment = data; factor = { id: data.id };
    }
    await new Promise((resolve, reject) => {
        const dialog = document.createElement('dialog'); dialog.className = 'admin-mfa-dialog';
        dialog.setAttribute('aria-labelledby', 'adminMfaTitle');
        dialog.innerHTML = `<form><h2 id="adminMfaTitle">${enrollment ? 'Set up administrator verification' : 'Verify your sign-in'}</h2>
            <p>${enrollment ? 'Add IronGrind to your authenticator app, then enter its six-digit code.' : 'Enter the six-digit code from your authenticator app.'}</p>
            <div class="admin-mfa-enrollment" hidden><img alt="Authenticator setup QR"><label>Manual setup key<input readonly></label></div>
            <label for="adminMfaCode">Verification code</label><input id="adminMfaCode" inputmode="numeric" autocomplete="one-time-code" pattern="[0-9]{6}" maxlength="6" required>
            <p class="admin-mfa-status" role="status" aria-live="polite"></p>
            <div class="modal-actions"><button type="button" class="btn-sm">Cancel sign-in</button><button type="submit" class="btn-primary">Verify</button></div>
            <small>Authenticator unavailable? Contact the project owner for verified account recovery.</small></form>`;
        document.body.append(dialog);
        if (enrollment) {
            const panel = dialog.querySelector('.admin-mfa-enrollment'); panel.hidden = false;
            panel.querySelector('img').src = enrollment.totp.qr_code;
            panel.querySelector('input').value = enrollment.totp.secret;
        }
        const input = dialog.querySelector('#adminMfaCode'), status = dialog.querySelector('[role="status"]');
        const verify = dialog.querySelector('button[type="submit"]');
        let finished = false;
        function finish(error) {
            if (finished) return; finished = true;
            dialog.close(); dialog.remove();
            error ? reject(error) : resolve();
        }
        dialog.querySelector('button[type="button"]').onclick = () => finish(new Error('Sign-in cancelled.'));
        dialog.addEventListener('cancel', event => { event.preventDefault(); finish(new Error('Sign-in cancelled.')); });
        dialog.querySelector('form').onsubmit = async event => {
            event.preventDefault(); if (verify.disabled) return;
            verify.disabled = true; status.textContent = 'Verifying…';
            try {
                const { error } = await client.auth.mfa.challengeAndVerify({ factorId: factor.id, code: input.value.trim() });
                if (error) throw error;
                const { data, error: checkError } = await client.auth.mfa.getAuthenticatorAssuranceLevel();
                if (checkError || data.currentLevel !== 'aal2') throw new Error('Verification could not be confirmed.');
                finish();
            } catch { status.textContent = 'Code not accepted. Use the current code from your authenticator and try again.'; input.value = ''; input.focus(); }
            finally { verify.disabled = false; }
        };
        dialog.showModal(); input.focus();
    });
};
