// IndexedDB holds a non-extractable ECDSA private key; the server stores only its public key.
window.readAdminDeviceKey = async () => {
    if (!window.isSecureContext || !window.indexedDB || !crypto.subtle) throw new Error('Trusted-device sign-in requires HTTPS and browser storage.');
    const db = await new Promise((resolve, reject) => {
        const request = indexedDB.open('irongrind-admin-device', 1);
        request.onupgradeneeded = () => request.result.createObjectStore('keys');
        request.onsuccess = () => resolve(request.result); request.onerror = () => reject(new Error('Browser device storage is unavailable.'));
    });
    try {
        const existing = await new Promise((resolve, reject) => {
            const request = db.transaction('keys', 'readonly').objectStore('keys').get('device');
            request.onsuccess = () => resolve(request.result); request.onerror = () => reject(request.error);
        });
        if (existing?.privateKey && existing.publicKey && existing.deviceId) return existing;
        const pair = await crypto.subtle.generateKey({ name: 'ECDSA', namedCurve: 'P-256' }, false, ['sign', 'verify']);
        const value = { deviceId: crypto.randomUUID(), privateKey: pair.privateKey, publicKey: await crypto.subtle.exportKey('jwk', pair.publicKey) };
        // add, not put: another tab may have won the first-enrollment storage race.
        await new Promise((resolve, reject) => {
            const transaction = db.transaction('keys', 'readwrite'); transaction.objectStore('keys').add(value, 'device');
            transaction.oncomplete = () => resolve(); transaction.onerror = transaction.onabort = () => reject(transaction.error);
        });
        return value;
    } catch (error) {
        if (error?.name === 'ConstraintError') return window.readAdminDeviceKey();
        throw new Error('Could not store this browser’s device key. Allow site storage and try again.');
    } finally { db.close(); }
};

window.prepareAdminDeviceTrust = async (client, scope) => {
    const device = await window.readAdminDeviceKey();
    async function call(body) {
        const { data, error } = await client.functions.invoke('admin-device-trust', { body });
        if (error) {
            let message;
            try { message = (await error.context?.json?.())?.error; } catch {}
            throw new Error(message || 'Device security setup is unavailable. Contact the project owner.');
        }
        if (!data) throw new Error('Device verification returned no result.');
        return data;
    }
    const challenge = await call({ action: 'challenge', deviceId: device.deviceId, publicKey: device.publicKey, scope });
    if (typeof challenge.message !== 'string') throw new Error('Device challenge is unavailable.');
    return {
        reusable: challenge.reusable === true,
        complete: async () => {
            const proof = await crypto.subtle.sign({ name: 'ECDSA', hash: 'SHA-256' }, device.privateKey, new TextEncoder().encode(challenge.message));
            const signature = btoa(String.fromCharCode(...new Uint8Array(proof)));
            const result = await call({ action: 'complete', signature, label: String(navigator.userAgent || 'Browser').slice(0, 180) });
            if (result.authorized !== true) throw new Error('Device verification was not confirmed.');
        }
    };
};

window.requireAdminMfa = async (client, scope = 'dashboard') => {
    const { data: required, error } = await client.rpc('admin_mfa_required');
    if (error) throw new Error('Could not check sign-in security. Confirm the security setup is deployed.');
    if (required !== true) return;
    const device = await window.prepareAdminDeviceTrust(client, scope);
    if (!device.reusable) {
        if (!window.waitForAdminDeviceApproval) throw new Error('Device approval could not load. Reload the page and sign in again.');
        const approved = await window.waitForAdminDeviceApproval(client, scope);
        await window.verifyAdminAuthenticator(client, true);
        // A sleeping trusted browser can resume while the authenticator is open.
        // Ask again so completion cannot require approval we never requested.
        if (!approved) await window.waitForAdminDeviceApproval(client, scope);
    }
    await device.complete();
};

window.forgetAdminDevice = async client => {
    const { error } = await client.rpc('forget_admin_trusted_device');
    if (error) throw new Error('Could not revoke device trust. Check your connection and try again.');
};

window.loadAdminTrustedDeviceInfo = async () => {
    const target = document.getElementById('adminTrustedDeviceInfo');
    if (!target || !window.ironGrindSupabase) return;
    const detail = target.querySelector('small');
    if (detail) detail.textContent = 'Checking registered browser…';
    let result;
    try { result = await window.ironGrindSupabase.rpc('get_admin_trusted_device'); }
    catch { result = { error: true }; }
    const { data, error } = result;
    if (!target.isConnected) return;
    if (error) {
        if (detail) detail.textContent = 'Device details are unavailable.';
        return;
    }
    const device = Array.isArray(data) ? data[0] : data;
    if (!device?.device_label) {
        if (detail) detail.textContent = 'No trusted browser is currently registered.';
        return;
    }
    const ua = device.device_label;
    const browser = /Edg\//.test(ua) ? 'Microsoft Edge' : /Firefox\//.test(ua) ? 'Firefox' : /Chrome\//.test(ua) ? 'Chrome' : /Safari\//.test(ua) ? 'Safari' : 'Browser';
    const platform = /Android/i.test(ua) ? 'Android' : /iPhone|iPad|iPod/i.test(ua) ? 'iPhone/iPad' : /Windows/i.test(ua) ? 'Windows' : /Macintosh|Mac OS/i.test(ua) ? 'Mac' : /Linux/i.test(ua) ? 'Linux' : 'device';
    if (detail) detail.textContent = `${browser} on ${platform} · registered browser`;
};
