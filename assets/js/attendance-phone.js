let phoneAttendanceScanner = null;
let phoneScanBusy = false;
let deferredPhoneInstallPrompt = null;
let phoneScannerMode = 'pair';
let activePhoneSession = null;

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
    const scanner = new Html5Qrcode('phoneQrReader');
    phoneAttendanceScanner = scanner;
    return scanner;
}

function setPhoneCameraButton(running) {
    const button = document.getElementById('phoneCameraButton');
    if (button) button.textContent = running ? 'Stop camera' : 'Start camera';
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
                let pairingUrl;
                try { pairingUrl = new URL(decodedText.trim()); } catch { return; }
                if (pairingUrl.origin !== window.location.origin || !pairingUrl.pathname.endsWith('/attendance-phone.html')) return;
                const sessionId = pairingUrl.searchParams.get('session');
                const token = pairingUrl.searchParams.get('token');
                if (!sessionId || !token) return;
                phoneScanBusy = true;
                setPhoneAttendanceStatus('Admin pairing QR detected. Connecting…');
                await stopPhoneAttendanceScanner();
                window.history.replaceState(null, '', window.location.pathname);
                await startPhoneMemberScanner(sessionId, token);
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

async function startPhoneMemberScanner(sessionId, token) {
    phoneScannerMode = 'member';
    activePhoneSession = { sessionId, token };
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
        await startPhonePairingScanner('Pairing expired or invalid. Scan a new pairing QR from the admin page.');
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
                phoneScanBusy = true;
                try { scanner.pause(true); } catch {}
                setPhoneAttendanceStatus('QR detected. Sending attendance scan…');
                try {
                    const { error } = await window.ironGrindSupabase.rpc('submit_mobile_attendance_scan', {
                        p_session_id: sessionId,
                        p_token: token,
                        p_qr_payload: decodedText.trim()
                    });
                    if (phoneAttendanceScanner !== scanner) return;
                    if (error) {
                        const expired = error.message?.includes('expired') || error.message?.includes('invalid');
                        setPhoneAttendanceStatus(expired
                            ? 'This pairing has expired. Start Phone Camera again on the admin page and rescan its QR.'
                            : `Could not send the scan: ${error.message}`, true);
                        if (expired) {
                            await stopPhoneAttendanceScanner();
                            await startPhonePairingScanner('Pairing expired. Scan a new pairing QR from the admin page.');
                            return;
                        }
                    } else {
                        setPhoneAttendanceStatus('Scan sent. Ready for the next member.');
                    }
                } catch (error) {
                    setPhoneAttendanceStatus(`Connection issue: ${error.message || 'Scan could not be sent.'}`, true);
                }
                window.setTimeout(() => {
                    if (phoneAttendanceScanner === scanner) {
                        phoneScanBusy = false;
                        try { scanner.resume(); } catch {}
                    }
                }, 1200);
            },
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

async function stopPhoneAttendanceScanner() {
    const scanner = phoneAttendanceScanner;
    phoneAttendanceScanner = null;
    phoneScanBusy = false;
    setPhoneCameraButton(false);
    if (scanner) {
        const track = scanner.getRunningTrack?.();
        try { await scanner.stop(); } catch {}
        try { track?.stop(); } catch {}
        try { scanner.clear(); } catch {}
    }
    setPhoneAttendanceStatus('Camera stopped. You can close this page.');
}

async function togglePhoneAttendanceCamera() {
    if (phoneAttendanceScanner) {
        await stopPhoneAttendanceScanner();
        return;
    }
    if (phoneScannerMode === 'member' && activePhoneSession) {
        await startPhoneMemberScanner(activePhoneSession.sessionId, activePhoneSession.token);
    } else {
        await startPhonePairingScanner();
    }
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
        navigator.serviceWorker.register('attendance-phone-sw.js').catch(error => console.warn('Attendance app offline shell could not be registered:', error));
    }
    if (!window.ironGrindSupabase) {
        setPhoneAttendanceStatus('The attendance service could not load. Check your connection and reload.', true);
        return;
    }
    const params = new URLSearchParams(window.location.search);
    const sessionId = params.get('session');
    const token = params.get('token');
    if (sessionId && token) {
        window.history.replaceState(null, '', window.location.pathname);
        await startPhoneMemberScanner(sessionId, token);
    } else {
        await startPhonePairingScanner();
    }
}

startPhoneAttendanceApp();
