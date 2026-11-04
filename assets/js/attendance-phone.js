let phoneAttendanceScanner = null;
const phonePairingClient = window.supabase?.createClient(IRON_GRIND_SUPABASE_URL, IRON_GRIND_SUPABASE_PUBLISHABLE_KEY, { auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false, storageKey: 'ig_phone_pairing_transport' } });
let phoneOperator = null;
let phoneOperatorClient = null;
let pendingPhoneScan = null;
function requirePhoneOperator() {
    if (phoneOperator) return true;
    document.getElementById('phoneOperatorSetup').hidden = false;
    setPhoneAttendanceStatus('Sign in with your assigned staff or admin username before opening the camera.');
    return false;
}
async function signInPhoneOperator(event) {
    event.preventDefault();
    const button = document.getElementById('phoneOperatorSignIn');
    button.disabled = true;
    try {
        phoneOperatorClient ||= window.supabase.createClient(IRON_GRIND_SUPABASE_URL, IRON_GRIND_SUPABASE_PUBLISHABLE_KEY, {
            auth: { persistSession: false, detectSessionInUrl: false, autoRefreshToken: true, storageKey: 'ig_phone_operator_memory' }
        });
        const username = document.getElementById('phoneOperatorId').value.trim();
        const password = document.getElementById('phoneOperatorPassword').value;
        const { data, error } = await phoneOperatorClient.functions.invoke('admin-username-login', { body: { username, password } });
        if (error) {
            const detail = await error.context?.json?.().catch(() => null);
            throw new Error(detail?.error || error.message);
        }
        if (!data?.session) throw new Error(data?.error || 'Sign-in failed.');
        const { error: sessionError } = await phoneOperatorClient.auth.setSession(data.session);
        if (sessionError) throw sessionError;
        const { data: { user }, error: userError } = await phoneOperatorClient.auth.getUser();
        if (userError || !user) throw new Error('Could not verify your sign-in.');
        const { data: profile, error: profileError } = await phoneOperatorClient.from('profiles').select('role,full_name,is_active').eq('id', user.id).single();
        if (profileError || !profile?.is_active || !['staff', 'admin'].includes(profile.role)) throw new Error('Active staff or admin account required.');
        phoneOperatorClient.auth.startAutoRefresh();
        phoneOperator = { id: user.id, name: profile.full_name || username };
        document.getElementById('phoneOperatorSetup').hidden = true;
        document.getElementById('phoneOperatorIdentity').hidden = false;
        document.getElementById('phoneOperatorName').textContent = 'Operator: ' + phoneOperator.name;
        const pairing = readPhonePairing();
        if (pairing) await startPhoneMemberScanner(pairing.sessionId, pairing.token, false);
        else setPhoneAttendanceStatus('Signed in. Tap Open pairing camera to pair this phone once.');
    } catch (error) { setPhoneAttendanceStatus(error.message || 'Could not sign in.', true); }
    finally { document.getElementById('phoneOperatorPassword').value = ''; button.disabled = false; }
}
async function changePhoneOperator() {
    await stopPhoneAttendanceScanner();
    await phoneOperatorClient?.auth.signOut();
    phoneOperator = null;
    pendingPhoneScan = null;
    document.getElementById('phoneOperatorIdentity').hidden = true;
    requirePhoneOperator();
}
let phoneScanBusy = false;
let deferredPhoneInstallPrompt = null;
let phoneScannerMode = 'pair';
let activePhoneSession = null;
let phoneCameraPausedForNextMember = false;
let phoneCameraTransition = false;
let phoneModelSetupOpenCamera = true;
const PHONE_PAIRING_STORAGE_KEY = 'ig_remembered_attendance_phone_pairing';
const TEMP_PHONE_PAIRING_STORAGE_KEY = 'ig_temporary_attendance_phone_pairing';
const PHONE_MODEL_STORAGE_KEY = 'ig_attendance_phone_model';

function setPhoneAttendanceStatus(message, isError = false) {
    const status = document.getElementById('phoneQrStatus');
    if (!status) return;
    status.textContent = message;
    status.classList.toggle('error', isError);
}

function setPhoneAttendanceMode(mode) {
    const instructions = document.getElementById('phoneScannerInstructions');
    if (instructions) instructions.textContent = mode === 'pair'
        ? 'On the admin page choose Attendance → Phone Camera, then point this camera at the pairing QR.'
        : 'Scan a member QR. Attendance is saved directly under your signed-in operator account.';
}

function isPhoneCameraAvailable() {
    return window.isSecureContext && Boolean(navigator.mediaDevices?.getUserMedia);
}

function createPhoneQrScanner() {
    if (typeof Html5Qrcode === 'undefined') throw new Error('The scanner library could not load. Check your internet connection.');
    const reader = document.getElementById('phoneQrReader');
    if (reader) {
        reader.querySelectorAll('video').forEach(video => {
            try { video.pause(); } catch {}
            try { video.srcObject?.getTracks().forEach(track => track.stop()); } catch {}
            video.srcObject = null;
        });
        reader.replaceChildren();
    }
    const scanner = new Html5Qrcode('phoneQrReader');
    phoneAttendanceScanner = scanner;
    return scanner;
}

function setPhoneCameraButton(running) {
    const button = document.getElementById('phoneCameraButton');
    if (button) button.textContent = running ? 'Stop camera' : phoneScannerMode === 'member' && activePhoneSession ? 'Open camera' : 'Open pairing camera';
}

function setPhoneNextScanButton(visible, label = 'Scan next member') {
    const button = document.getElementById('phoneNextScanButton');
    if (!button) return;
    button.hidden = !visible;
    button.textContent = label;
}

async function confirmPhoneCameraPreview() {
    const video = document.querySelector('#phoneQrReader video');
    if (!video) throw new Error('Camera opened without a video preview. Close other camera apps and try again.');
    video.muted = true;
    video.autoplay = true;
    video.playsInline = true;
    try { await video.play(); } catch {}
    if (video.readyState >= HTMLMediaElement.HAVE_CURRENT_DATA && video.videoWidth > 0) return;
    await Promise.race([
        new Promise(resolve => video.addEventListener('loadeddata', resolve, { once: true })),
        new Promise(resolve => window.setTimeout(resolve, 2500))
    ]);
    if (!video.videoWidth) throw new Error('Camera permission was granted, but its preview stayed blank. Close other camera apps, then tap Open camera again.');
}

async function getPhoneDeviceLabel() {
    const ua = navigator.userAgent || '';
    let model = '';
    try {
        const hints = await navigator.userAgentData?.getHighEntropyValues?.(['model', 'platform']);
        model = String(hints?.model || '').trim();
    } catch {}
    if (!model) {
        const uaModel = ua.match(/Android[^;)]*;\s*([^;)]+?)(?:\s+Build\/|[;)])/i)?.[1]?.trim();
        if (uaModel && !/^(?:K|wv|Linux|Android|Mobile)$/i.test(uaModel)) model = uaModel;
    }
    if (model && !/^(?:unknown|generic)$/i.test(model)) return model;
    return String(localStorage.getItem(PHONE_MODEL_STORAGE_KEY) || '').trim();
}

async function registerPhoneAttendanceDevice(sessionId, token) {
    const deviceLabel = await getPhoneDeviceLabel();
    if (!deviceLabel) return { error: null, deviceLabel: '' };
    const result = await phonePairingClient.rpc('register_mobile_attendance_device', {
        p_session_id: sessionId,
        p_token: token,
        p_device_label: deviceLabel
    });
    return { ...result, deviceLabel };
}

function requestPhoneModelSetup(openCamera = true) {
    phoneModelSetupOpenCamera = openCamera;
    const setup = document.getElementById('phoneModelSetup');
    const input = document.getElementById('phoneModelInput');
    if (input) input.value = localStorage.getItem(PHONE_MODEL_STORAGE_KEY) || '';
    if (setup) setup.hidden = false;
    const cameraButton = document.getElementById('phoneCameraButton');
    if (cameraButton && !phoneAttendanceScanner) cameraButton.disabled = true;
    setPhoneAttendanceStatus('Your browser hides the exact phone model. Enter it below to finish pairing.');
    window.setTimeout(() => input?.focus(), 50);
}

async function savePhoneModelAndContinue() {
    const input = document.getElementById('phoneModelInput');
    const button = document.getElementById('phoneModelSaveButton');
    const model = String(input?.value || '').trim().slice(0, 100);
    if (!model) {
        setPhoneAttendanceStatus('Enter the exact model name or number from Settings → About phone.', true);
        input?.focus();
        return;
    }
    if (!activePhoneSession) {
        setPhoneAttendanceStatus('This pairing is no longer active. Start a new pairing from the admin page.', true);
        return;
    }
    if (button) button.disabled = true;
    localStorage.setItem(PHONE_MODEL_STORAGE_KEY, model);
    try {
        const { error } = await phonePairingClient.rpc('register_mobile_attendance_device', {
            p_session_id: activePhoneSession.sessionId,
            p_token: activePhoneSession.token,
            p_device_label: model
        });
        if (error) throw error;
        const setup = document.getElementById('phoneModelSetup');
        if (setup) setup.hidden = true;
        const cameraButton = document.getElementById('phoneCameraButton');
        if (cameraButton) cameraButton.disabled = false;
        if (phoneAttendanceScanner) {
            try { phoneAttendanceScanner.pause(true); } catch {}
            phoneCameraPausedForNextMember = true;
            setPhoneCameraButton(true);
            setPhoneNextScanButton(true, 'Scan member QR');
            setPhoneAttendanceMode('scan');
            setPhoneAttendanceStatus(`Paired phone: ${model}. Remove the pairing QR, then tap Scan member QR.`);
        } else if (phoneModelSetupOpenCamera) {
            await startPhoneMemberScanner(activePhoneSession.sessionId, activePhoneSession.token, true);
        } else {
            setPhoneCameraButton(false);
            setPhoneAttendanceMode('scan');
            setPhoneAttendanceStatus(`Paired phone: ${model}. Tap Open camera when ready.`);
        }
    } catch (error) {
        setPhoneAttendanceStatus(`Could not save the phone model: ${error.message || 'Check the connection and try again.'}`, true);
    } finally {
        if (button) button.disabled = false;
    }
}

function savePhonePairing(sessionId, token, remember, expiresAt = '') {
    const value = JSON.stringify({ sessionId, token, expiresAt });
    const destination = remember ? localStorage : sessionStorage;
    const other = remember ? sessionStorage : localStorage;
    destination.setItem(remember ? PHONE_PAIRING_STORAGE_KEY : TEMP_PHONE_PAIRING_STORAGE_KEY, value);
    other.removeItem(remember ? TEMP_PHONE_PAIRING_STORAGE_KEY : PHONE_PAIRING_STORAGE_KEY);
}

function readPhonePairing() {
    for (const [storage, key] of [[localStorage, PHONE_PAIRING_STORAGE_KEY], [sessionStorage, TEMP_PHONE_PAIRING_STORAGE_KEY]]) {
        try {
            const value = JSON.parse(storage.getItem(key) || 'null');
            if (value?.sessionId && value?.token) return value;
        } catch { storage.removeItem(key); }
    }
    return null;
}

function clearPhonePairing() {
    localStorage.removeItem(PHONE_PAIRING_STORAGE_KEY);
    sessionStorage.removeItem(TEMP_PHONE_PAIRING_STORAGE_KEY);
}

async function startPhonePairingScanner(statusMessage = '') {
    if (!requirePhoneOperator()) return;
    phoneScannerMode = 'pair';
    activePhoneSession = null;
    setPhoneCameraButton(false);
    setPhoneAttendanceMode('pair');
    if (!isPhoneCameraAvailable()) {
        setPhoneAttendanceStatus('Camera access requires the hosted HTTPS website. Open this app on your phone over HTTPS.', true);
        return;
    }
    let scanner;
    try {
        scanner = createPhoneQrScanner();
        await scanner.start(
            { facingMode: 'environment' },
            { fps: 10, qrbox: { width: 250, height: 250 }, aspectRatio: 1 },
            async decodedText => {
                if (phoneScanBusy || phoneAttendanceScanner !== scanner) return;
                if (phoneScannerMode === 'member' && activePhoneSession) {
                    await submitPhoneMemberScan(decodedText, scanner, activePhoneSession);
                    return;
                }
                let pairingUrl;
                try { pairingUrl = new URL(decodedText.trim()); } catch { return; }
                if (pairingUrl.origin !== window.location.origin || !pairingUrl.pathname.endsWith('/attendance-phone.html')) return;
                const sessionId = pairingUrl.searchParams.get('session');
                const token = pairingUrl.searchParams.get('token');
                if (!sessionId || !token) return;
                phoneScanBusy = true;
                try { scanner.pause(true); } catch {}
                setPhoneAttendanceStatus('Admin pairing QR detected. Connecting…');
                savePhonePairing(sessionId, token, pairingUrl.searchParams.get('remember') === '1', pairingUrl.searchParams.get('expires') || '');
                try {
                    const { data: sessionValid, error } = await phonePairingClient.rpc('validate_mobile_attendance_scan_session', {
                        p_session_id: sessionId,
                        p_token: token
                    });
                    if (error || sessionValid !== true) {
                        if (!error) clearPhonePairing();
                        setPhoneAttendanceStatus(error
                            ? `Could not validate pairing: ${error.message}`
                            : 'Supabase rejected this pairing. It may have expired, or the pairing migrations may not be applied. Create a fresh QR on the admin page.', true);
                    } else {
                        const { error: deviceError, deviceLabel } = await registerPhoneAttendanceDevice(sessionId, token);
                        phoneScannerMode = 'member';
                        activePhoneSession = { sessionId, token };
                        phoneCameraPausedForNextMember = true;
                        setPhoneAttendanceMode('scan');
                        if (deviceError) {
                            setPhoneNextScanButton(false);
                            setPhoneAttendanceStatus(`Pairing succeeded, but the phone model could not be saved: ${deviceError.message}`, true);
                        } else if (!deviceLabel) {
                            setPhoneNextScanButton(false);
                            requestPhoneModelSetup(true);
                        } else {
                            setPhoneNextScanButton(true, 'Scan member QR');
                            setPhoneAttendanceStatus(`Phone paired: ${deviceLabel}. Remove the pairing QR, then tap Scan member QR.`);
                        }
                    }
                } catch (error) {
                    setPhoneAttendanceStatus(`Could not validate pairing: ${error.message || 'Check your connection.'}`, true);
                }
                window.setTimeout(() => {
                    if (phoneAttendanceScanner === scanner) {
                        phoneScanBusy = false;
                        if (phoneScannerMode === 'member' && activePhoneSession) {
                            phoneCameraPausedForNextMember = true;
                            setPhoneCameraButton(true);
                            if (!document.getElementById('phoneModelSetup')?.hidden) setPhoneNextScanButton(false);
                            else setPhoneNextScanButton(true, 'Scan member QR');
                        } else {
                            try { scanner.resume(); } catch {}
                        }
                    }
                }, 1200);
            },
            () => {}
        );
        await confirmPhoneCameraPreview();
        setPhoneCameraButton(true);
        setPhoneAttendanceStatus(statusMessage || 'Camera is on. Scan the pairing QR shown on the admin page.');
    } catch (error) {
        try { await scanner?.stop(); } catch {}
        try { scanner?.getRunningTrack?.()?.stop(); } catch {}
        phoneAttendanceScanner = null;
        setPhoneCameraButton(false);
        setPhoneAttendanceStatus(error?.name === 'NotAllowedError'
            ? 'Camera permission was denied. Allow camera access in your browser settings.'
            : `Could not start the camera: ${error.message || 'Check camera permissions.'}`, true);
        try { scanner?.clear(); } catch {}
    }
}

async function startPhoneMemberScanner(sessionId, token, openCamera = true) {
    if (!requirePhoneOperator()) return;
    phoneScannerMode = 'member';
    activePhoneSession = { sessionId, token };
    phoneCameraPausedForNextMember = false;
    setPhoneNextScanButton(false);
    setPhoneCameraButton(false);
    setPhoneAttendanceMode('scan');
    if (!isPhoneCameraAvailable()) {
        setPhoneAttendanceStatus('Camera access requires the hosted HTTPS website.', true);
        return;
    }
    const { data: sessionValid, error: sessionError } = await phonePairingClient.rpc('validate_mobile_attendance_scan_session', {
        p_session_id: sessionId,
        p_token: token
    });
    if (sessionError) {
        setPhoneAttendanceStatus('Could not check pairing. Your saved connection was kept. Check your internet and tap Open camera to retry.', true);
        return;
    }
    if (sessionValid !== true) {
        clearPhonePairing();
        await startPhonePairingScanner(sessionError
            ? `Could not validate pairing: ${sessionError.message}`
            : 'Supabase rejected this pairing. It may have expired, or the pairing migrations may not be applied. Scan a fresh QR from the admin page.');
        return;
    }
    const { error: deviceError, deviceLabel } = await registerPhoneAttendanceDevice(sessionId, token);
    if (deviceError) console.warn('Could not register the paired attendance phone:', deviceError.message);
    if (!deviceError && !deviceLabel) {
        requestPhoneModelSetup(openCamera);
        return;
    }
    if (!openCamera) {
        setPhoneCameraButton(false);
        setPhoneAttendanceStatus(deviceError
            ? 'This phone is paired, but its device name could not be updated. Ask the admin to check the latest phone-pairing migration; do not rerun older migrations.'
            : `This phone is paired: ${deviceLabel}. Tap Open camera when ready.`);
        return;
    }
    let scanner;
    try {
        scanner = createPhoneQrScanner();
        await scanner.start(
            { facingMode: 'environment' },
            { fps: 10, qrbox: { width: 250, height: 250 }, aspectRatio: 1 },
            decodedText => submitPhoneMemberScan(decodedText, scanner, { sessionId, token }),
            () => {}
        );
        await confirmPhoneCameraPreview();
        phoneScanBusy = false;
        setPhoneCameraButton(true);
        setPhoneAttendanceStatus('Camera is on. Point it at a member QR code.');
    } catch (error) {
        try { await scanner?.stop(); } catch {}
        try { scanner?.getRunningTrack?.()?.stop(); } catch {}
        phoneAttendanceScanner = null;
        setPhoneCameraButton(false);
        setPhoneAttendanceStatus(error?.name === 'NotAllowedError'
            ? 'Camera permission was denied. Allow camera access in your browser settings.'
            : `Could not start the camera: ${error.message || 'Check camera permissions.'}`, true);
        try { scanner?.clear(); } catch {}
    }
}

async function submitPhoneMemberScan(decodedText, scanner, session) {
    if (!requirePhoneOperator() || phoneScanBusy || phoneAttendanceScanner !== scanner) return;
    phoneScanBusy = true;
    try { scanner.pause(true); } catch {}
    setPhoneAttendanceStatus('Saving attendance?');
    try {
        const payload = decodedText.trim();
        if (pendingPhoneScan && pendingPhoneScan.payload !== payload) throw new Error('The previous scan has not been confirmed. Scan that member again to retry safely.');
        pendingPhoneScan ||= { payload, requestId: crypto.randomUUID() };
        const { data, error } = await phoneOperatorClient.rpc('record_attendance_scan', {
            p_identifier: payload, p_request_id: pendingPhoneScan.requestId,
            p_session_id: session.sessionId, p_token: session.token
        });
        if (error) {
            // Database rejections did not commit; connection failures retain the retry identifier.
            if (error.code && error.code !== '') pendingPhoneScan = null;
            if (/pairing is invalid or expired/i.test(error.message)) {
                clearPhonePairing(); activePhoneSession = null; phoneScannerMode = 'pair';
            }
            throw error;
        }
        pendingPhoneScan = null;
        const action = data.action === 'duplicate' ? 'was already scanned just now. No extra visit was recorded.'
            : data.action === 'check_out' ? 'checked out.' : 'checked in.';
        setPhoneAttendanceStatus(data.member_name + ' ' + action + ' Operator: ' + phoneOperator.name);
    } catch (error) { setPhoneAttendanceStatus(error.message || 'Connection issue. Scan the same member again to retry safely.', true); }
    finally {
        if (phoneAttendanceScanner === scanner) {
            phoneCameraPausedForNextMember = true; phoneScanBusy = false;
            setPhoneCameraButton(true); setPhoneNextScanButton(true, pendingPhoneScan ? 'Retry member scan' : 'Scan next member');
        }
    }
}

async function stopPhoneAttendanceScanner() {
    const scanner = phoneAttendanceScanner;
    phoneAttendanceScanner = null;
    phoneScanBusy = false;
    phoneCameraPausedForNextMember = false;
    setPhoneNextScanButton(false);
    setPhoneCameraButton(false);
    if (scanner) {
        let track;
        try { track = scanner.getRunningTrack?.(); } catch {}
        try { await scanner.stop(); } catch {}
        try { track?.stop(); } catch {}
        try { scanner.clear(); } catch {}
    }
    const reader = document.getElementById('phoneQrReader');
    reader?.querySelectorAll('video').forEach(video => {
        try { video.pause(); } catch {}
        try { video.srcObject?.getTracks().forEach(track => track.stop()); } catch {}
        video.srcObject = null;
        video.removeAttribute('src');
        try { video.load(); } catch {}
    });
    reader?.replaceChildren();
    const deviceLabel = activePhoneSession ? await getPhoneDeviceLabel() : '';
    setPhoneAttendanceStatus(activePhoneSession
        ? deviceLabel
            ? `Camera stopped. ${deviceLabel} is still paired. Tap Open camera to continue scanning.`
            : 'Camera stopped. Your pairing is still active. Tap Open camera to continue scanning.'
        : 'Camera stopped. You can close this page.');
}

async function togglePhoneAttendanceCamera() {
    if (!requirePhoneOperator()) return;
    if (phoneCameraTransition) return;
    phoneCameraTransition = true;
    const cameraButton = document.getElementById('phoneCameraButton');
    const nextButton = document.getElementById('phoneNextScanButton');
    if (cameraButton) cameraButton.disabled = true;
    if (nextButton) nextButton.disabled = true;
    try {
        if (phoneAttendanceScanner) {
            await stopPhoneAttendanceScanner();
            return;
        }
        if (!activePhoneSession) {
            const savedPairing = readPhonePairing();
            if (savedPairing) {
                activePhoneSession = { sessionId: savedPairing.sessionId, token: savedPairing.token };
                phoneScannerMode = 'member';
            }
        }
        if (phoneScannerMode === 'member' && activePhoneSession) {
            await startPhoneMemberScanner(activePhoneSession.sessionId, activePhoneSession.token);
        } else {
            await startPhonePairingScanner();
        }
    } finally {
        phoneCameraTransition = false;
        if (cameraButton) cameraButton.disabled = !phoneAttendanceScanner && !document.getElementById('phoneModelSetup')?.hidden;
        if (nextButton) nextButton.disabled = false;
    }
}

function resumePhoneAttendanceScanner() {
    if (!requirePhoneOperator()) return;
    if (phoneCameraTransition || !phoneAttendanceScanner || !phoneCameraPausedForNextMember) return;
    phoneCameraPausedForNextMember = false;
    phoneScanBusy = false;
    setPhoneNextScanButton(false);
    try { phoneAttendanceScanner.resume(); } catch {}
    setPhoneCameraButton(true);
    setPhoneAttendanceStatus('Camera is on. Point it at the next member QR code.');
}

async function installPhoneAttendanceApp() {
    const help = document.getElementById('phoneInstallHelp');
    if (!deferredPhoneInstallPrompt) {
        if (help) help.style.display = 'block';
        return;
    }
    deferredPhoneInstallPrompt.prompt();
    await deferredPhoneInstallPrompt.userChoice;
    deferredPhoneInstallPrompt = null;
    document.getElementById('phoneInstallButton').style.display = 'none';
}

function configurePhoneAppInstall() {
    const installButton = document.getElementById('phoneInstallButton');
    const standalone = window.matchMedia('(display-mode: standalone)').matches || window.navigator.standalone === true;
    if (standalone) return;
    installButton.style.display = 'block';
    const isIOS = /iphone|ipad|ipod/i.test(navigator.userAgent);
    window.addEventListener('beforeinstallprompt', event => {
        event.preventDefault();
        deferredPhoneInstallPrompt = event;
        installButton.style.display = 'block';
    });
    window.addEventListener('appinstalled', () => { installButton.style.display = 'none'; });
}

window.addEventListener('pagehide', () => {
    phoneOperator = null;
    phoneOperatorClient?.auth.stopAutoRefresh();
    document.getElementById('phoneOperatorIdentity').hidden = true;
    document.getElementById('phoneOperatorSetup').hidden = false;
    const scanner = phoneAttendanceScanner;
    phoneAttendanceScanner = null;
    const reader = document.getElementById('phoneQrReader');
    if (scanner) {
        scanner.stop().catch(() => {}).finally(() => {
            try { scanner.clear(); } catch {}
            reader?.querySelectorAll('video').forEach(video => {
                try { video.srcObject?.getTracks().forEach(track => track.stop()); } catch {}
                video.srcObject = null;
            });
        });
    }
});

async function startPhoneAttendanceApp() {
    configurePhoneAppInstall();
    if ('serviceWorker' in navigator && window.isSecureContext) {
    navigator.serviceWorker.register('attendance-phone-sw.js?v=20261104-operator-scans').catch(error => console.warn('Attendance app offline shell could not be registered:', error));
    }
    if (!window.ironGrindSupabase) {
        setPhoneAttendanceStatus('The attendance service could not load. Check your connection and reload.', true);
        return;
    }
    const params = new URLSearchParams(window.location.search);
    const sessionId = params.get('session');
    const token = params.get('token');
    if (sessionId && token) {
        savePhonePairing(sessionId, token, params.get('remember') === '1', params.get('expires') || '');
        window.history.replaceState(null, '', window.location.pathname);
        requirePhoneOperator();
    } else {
        requirePhoneOperator();
        setPhoneCameraButton(false);
    }
}

window.addEventListener('pageshow', event => {
    if (event.persisted) {
        phoneScanBusy = false; phoneCameraTransition = false; phoneCameraPausedForNextMember = false;
        setPhoneNextScanButton(false); setPhoneCameraButton(false);
        requirePhoneOperator();
    }
});

startPhoneAttendanceApp();
