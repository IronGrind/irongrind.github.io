let phoneAttendanceScanner = null;
let phoneScanBusy = false;
let deferredPhoneInstallPrompt = null;
let phoneScannerMode = 'pair';
let activePhoneSession = null;
let phoneCameraPausedForNextMember = false;
let phoneCameraTransition = false;
const PHONE_PAIRING_STORAGE_KEY = 'ig_remembered_attendance_phone_pairing';
const TEMP_PHONE_PAIRING_STORAGE_KEY = 'ig_temporary_attendance_phone_pairing';

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
        : 'Point your phone camera at a member’s Iron Grind QR code. Attendance will be recorded on the paired admin page.';
}

function isPhoneCameraAvailable() {
    return window.isSecureContext && Boolean(navigator.mediaDevices?.getUserMedia);
}

function createPhoneQrScanner() {
    if (typeof Html5Qrcode === 'undefined') throw new Error('The scanner library could not load. Check your internet connection.');
    document.getElementById('phoneQrReader')?.replaceChildren();
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

async function getPhoneDeviceLabel() {
    const ua = navigator.userAgent || '';
    let platform = navigator.userAgentData?.platform || '';
    let model = '';
    let brand = navigator.userAgentData?.brands?.find(item => !/not.?a.?brand|chromium/i.test(item.brand))?.brand || '';
    try {
        const hints = await navigator.userAgentData?.getHighEntropyValues?.(['model', 'platform']);
        model = String(hints?.model || '').trim();
        platform = hints?.platform || platform;
    } catch {}
    const browser = /Edg\//.test(ua) || /Edge/i.test(brand) ? 'Edge'
        : /Firefox\//.test(ua) || /Firefox/i.test(brand) ? 'Firefox'
        : /Chrome\//.test(ua) || /Chrome/i.test(brand) ? 'Chrome'
        : /Safari\//.test(ua) ? 'Safari' : 'Browser';
    if (model && model.toLowerCase() !== 'unknown') return `${model} · ${browser}`;
    if (/Android/i.test(ua)) {
        const uaModel = ua.match(/Android[^;)]*;\s*([^;)]+?)(?:\s+Build\/|[;)])/i)?.[1]?.trim();
        const usefulModel = uaModel && !/^(?:K|wv|Linux|Android|Mobile)$/i.test(uaModel) ? uaModel : '';
        return `${usefulModel || (platform ? `${platform} phone` : 'Android phone')} · ${browser}`;
    }
    if (/iPhone/i.test(ua) || /iOS/i.test(platform)) return `iPhone · ${browser}`;
    if (/iPad/i.test(ua)) return `iPad · ${browser}`;
    return `Phone · ${browser}`;
}

async function registerPhoneAttendanceDevice(sessionId, token) {
    const deviceLabel = await getPhoneDeviceLabel();
    const result = await window.ironGrindSupabase.rpc('register_mobile_attendance_device', {
        p_session_id: sessionId,
        p_token: token,
        p_device_label: deviceLabel
    });
    return { ...result, deviceLabel };
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
                    const { data: sessionValid, error } = await window.ironGrindSupabase.rpc('validate_mobile_attendance_scan_session', {
                        p_session_id: sessionId,
                        p_token: token
                    });
                    if (error || sessionValid !== true) {
                        clearPhonePairing();
                        setPhoneAttendanceStatus(error
                            ? `Could not validate pairing: ${error.message}`
                            : 'Supabase rejected this pairing. It may have expired, or the pairing migrations may not be applied. Create a fresh QR on the admin page.', true);
                    } else {
                        const { error: deviceError, deviceLabel } = await registerPhoneAttendanceDevice(sessionId, token);
                        phoneScannerMode = 'member';
                        activePhoneSession = { sessionId, token };
                        phoneCameraPausedForNextMember = true;
                        setPhoneNextScanButton(true, 'Scan member QR');
                        setPhoneAttendanceMode('scan');
                        setPhoneAttendanceStatus(deviceError
                            ? 'Phone paired, but the admin page cannot show this device name yet. Apply migration 20261104000011.'
                            : `Phone paired as ${deviceLabel}. Remove the pairing QR, then tap Scan member QR.`);
                    }
                } catch (error) {
                    clearPhonePairing();
                    setPhoneAttendanceStatus(`Could not validate pairing: ${error.message || 'Check your connection.'}`, true);
                }
                window.setTimeout(() => {
                    if (phoneAttendanceScanner === scanner) {
                        phoneScanBusy = false;
                        if (phoneScannerMode === 'member' && activePhoneSession) {
                            phoneCameraPausedForNextMember = true;
                            setPhoneCameraButton(true);
                            setPhoneNextScanButton(true, 'Scan member QR');
                        } else {
                            try { scanner.resume(); } catch {}
                        }
                    }
                }, 1200);
            },
            () => {}
        );
        setPhoneCameraButton(true);
        setPhoneAttendanceStatus(statusMessage || 'Camera is on. Scan the pairing QR shown on the admin page.');
    } catch (error) {
        phoneAttendanceScanner = null;
        setPhoneCameraButton(false);
        setPhoneAttendanceStatus(error?.name === 'NotAllowedError'
            ? 'Camera permission was denied. Allow camera access in your browser settings.'
            : `Could not start the camera: ${error.message || 'Check camera permissions.'}`, true);
        try { scanner?.clear(); } catch {}
    }
}

async function startPhoneMemberScanner(sessionId, token, openCamera = true) {
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
    const { data: sessionValid, error: sessionError } = await window.ironGrindSupabase.rpc('validate_mobile_attendance_scan_session', {
        p_session_id: sessionId,
        p_token: token
    });
    if (sessionError || sessionValid !== true) {
        clearPhonePairing();
        await startPhonePairingScanner(sessionError
            ? `Could not validate pairing: ${sessionError.message}`
            : 'Supabase rejected this pairing. It may have expired, or the pairing migrations may not be applied. Scan a fresh QR from the admin page.');
        return;
    }
    const { error: deviceError, deviceLabel } = await registerPhoneAttendanceDevice(sessionId, token);
    if (deviceError) console.warn('Could not register the paired attendance phone:', deviceError.message);
    if (!openCamera) {
        setPhoneCameraButton(false);
        setPhoneAttendanceStatus(deviceError
            ? 'This phone is paired, but its device name cannot be shared until migration 20261104000011 is applied.'
            : `This phone is paired as ${deviceLabel}. Tap Open camera when ready.`);
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
        phoneScanBusy = false;
        setPhoneCameraButton(true);
        setPhoneAttendanceStatus('Camera is on. Point it at a member QR code.');
    } catch (error) {
        phoneAttendanceScanner = null;
        setPhoneCameraButton(false);
        setPhoneAttendanceStatus(error?.name === 'NotAllowedError'
            ? 'Camera permission was denied. Allow camera access in your browser settings.'
            : `Could not start the camera: ${error.message || 'Check camera permissions.'}`, true);
        try { scanner?.clear(); } catch {}
    }
}

async function submitPhoneMemberScan(decodedText, scanner, session) {
    if (phoneScanBusy || phoneAttendanceScanner !== scanner) return;
    phoneScanBusy = true;
    try { scanner.pause(true); } catch {}
    setPhoneAttendanceStatus('QR detected. Sending attendance scan…');
    try {
        const { error } = await window.ironGrindSupabase.rpc('submit_mobile_attendance_scan', {
            p_session_id: session.sessionId,
            p_token: session.token,
            p_qr_payload: decodedText.trim()
        });
        if (phoneAttendanceScanner !== scanner) return;
        if (error) {
            const expired = error.message?.includes('expired') || error.message?.includes('invalid');
            if (expired) {
                clearPhonePairing();
                activePhoneSession = null;
                phoneScannerMode = 'pair';
                setPhoneAttendanceMode('pair');
                setPhoneAttendanceStatus('Pairing expired. Scan a new pairing QR from the admin page.', true);
            } else {
                setPhoneAttendanceStatus(`Could not send the scan: ${error.message}`, true);
            }
        } else {
            setPhoneAttendanceStatus('Scan sent. Ready for the next member.');
        }
    } catch (error) {
        setPhoneAttendanceStatus(`Connection issue: ${error.message || 'Scan could not be sent.'}`, true);
    }
    if (phoneAttendanceScanner === scanner) {
        phoneCameraPausedForNextMember = true;
        phoneScanBusy = false;
        setPhoneCameraButton(true);
        setPhoneNextScanButton(true, 'Scan next member');
        if (!document.getElementById('phoneQrStatus')?.classList.contains('error')) {
            setPhoneAttendanceStatus('Scan sent. Remove the QR from view, then tap Scan next member.');
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
        const track = scanner.getRunningTrack?.();
        try { await scanner.stop(); } catch {}
        try { track?.stop(); } catch {}
        try { scanner.clear(); } catch {}
    }
    const deviceLabel = activePhoneSession ? await getPhoneDeviceLabel() : '';
    setPhoneAttendanceStatus(activePhoneSession
        ? `Camera stopped. ${deviceLabel} is still paired. Tap Open camera to continue scanning.`
        : 'Camera stopped. You can close this page.');
}

async function togglePhoneAttendanceCamera() {
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
        if (cameraButton) cameraButton.disabled = false;
        if (nextButton) nextButton.disabled = false;
    }
}

function resumePhoneAttendanceScanner() {
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
    const scanner = phoneAttendanceScanner;
    phoneAttendanceScanner = null;
    if (scanner) scanner.stop().catch(() => {});
});

async function startPhoneAttendanceApp() {
    configurePhoneAppInstall();
    if ('serviceWorker' in navigator && window.isSecureContext) {
        navigator.serviceWorker.register('attendance-phone-sw.js?v=20261104-phone-model').catch(error => console.warn('Attendance app offline shell could not be registered:', error));
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
        await startPhoneMemberScanner(sessionId, token);
    } else {
        const savedPairing = readPhonePairing();
        if (savedPairing) await startPhoneMemberScanner(savedPairing.sessionId, savedPairing.token, false);
        else await startPhonePairingScanner();
    }
}

startPhoneAttendanceApp();
