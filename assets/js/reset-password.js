(() => {
    const client = window.ironGrindSupabase;
    const loading = document.getElementById('recoveryLoading');
    const form = document.getElementById('resetPasswordForm');
    const errorBox = document.getElementById('recoveryError');
    const errorText = document.getElementById('recoveryErrorText');
    const successBox = document.getElementById('recoverySuccess');
    const statusBox = document.getElementById('resetStatus');
    const statusText = document.getElementById('resetStatusText');
    const saveButton = document.getElementById('savePasswordButton');
    let recoveryReady = false;

    function showRecoveryError(message) {
        loading.classList.add('hidden');
        form.classList.add('hidden');
        errorText.textContent = message;
        errorBox.classList.remove('hidden');
    }

    function enablePasswordForm() {
        recoveryReady = true;
        loading.classList.add('hidden');
        errorBox.classList.add('hidden');
        form.classList.remove('hidden');
        document.getElementById('newPassword').focus();
    }

    async function initializeRecovery() {
        const urlParams = new URLSearchParams(window.location.search);
        const hashParams = new URLSearchParams(window.location.hash.replace(/^#/, ''));
        const authError = urlParams.get('error_description') || hashParams.get('error_description');
        if (authError) {
            showRecoveryError('This reset link is invalid or expired. Request a new password reset email and try again.');
            return;
        }
        if (!client) {
            showRecoveryError('The sign-in service is unavailable. Refresh the page or contact the gym for help.');
            return;
        }

        client.auth.onAuthStateChange((event, session) => {
            if (event === 'PASSWORD_RECOVERY' && session) enablePasswordForm();
        });

        const { error } = await client.auth.getSession();
        if (error) {
            showRecoveryError('We could not verify this reset link. Request a new one and try again.');
            return;
        }
        // A regular signed-in session is not proof that this reset link is
        // valid. Wait for Supabase to confirm a PASSWORD_RECOVERY session.
        window.setTimeout(() => {
            if (!recoveryReady) showRecoveryError('This link did not start a password recovery session. Request a new reset email, then open the newest link in this browser.');
        }, 10000);
    }

    form.addEventListener('submit', async (event) => {
        event.preventDefault();
        if (!recoveryReady) return;
        const password = document.getElementById('newPassword').value;
        const confirmation = document.getElementById('confirmPassword').value;
        statusBox.classList.add('hidden');
        if (!newPasswordValid(password, 8)) {
            statusText.textContent = newPasswordMessage(8);
            statusBox.classList.remove('hidden');
            return;
        }
        if (password !== confirmation) {
            statusText.textContent = 'The passwords do not match.';
            statusBox.classList.remove('hidden');
            return;
        }

        saveButton.disabled = true;
        saveButton.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Saving…';
        try {
            const { error } = await client.auth.updateUser({ password });
            if (error) throw error;
            form.classList.add('hidden');
            document.getElementById('resetIntro').textContent = 'Password updated successfully.';
            successBox.classList.remove('hidden');
            try {
                await client.auth.signOut();
            } catch (signOutError) {
                console.warn('Password changed, but the recovery session could not be closed:', signOutError);
            }
        } catch (error) {
            console.error('Password reset failed:', error);
            const reason = error instanceof Error && error.message ? ` ${error.message}` : '';
            statusText.textContent = `We could not update your password.${reason} If this is a recovery link, request a new one and open the newest email.`;
            statusBox.classList.remove('hidden');
            saveButton.disabled = false;
            saveButton.innerHTML = '<i class="fas fa-lock"></i> Save New Password';
        }
    });

    initializeRecovery();
})();
