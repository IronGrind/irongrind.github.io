let phoneAttendanceScanner = null;
let phoneScanBusy = false;

function setPhoneAttendanceStatus(message, isError = false) {
    const status = document.getElementById('phoneQrStatus');
    if (!status) return;
    status.textContent = message;
    status.classList.toggle('error', isError);
}

async function startPhoneAttendanceScanner() {
    const params = new URLSearchParams(window.location.search);
    const sessionId = params.get('session');
    const token = params.get('token');
    if (!sessionId || !token) {
        setPhoneAttendanceStatus('This pairing link is incomplete. Start Phone Camera again from the admin page.', true);
        return;
    }
    if (!window.isSecureContext || !navigator.mediaDevices?.getUserMedia) {
        setPhoneAttendanceStatus('Camera access requires the hosted HTTPS website. Open this link in your phone browser.', true);
        return;
    }
    if (typeof Html5Qrcode === 'undefined' || !window.ironGrindSupabase) {
        setPhoneAttendanceStatus('The scanner could not load. Check your connection and reopen the pairing link.', true);
        return;
    }

    const scanner = new Html5Qrcode('phoneQrReader');
    phoneAttendanceScanner = scanner;
    try {
        await scanner.start(
            { facingMode: 'environment' },
            { fps: 10, qrbox: { width: 250, height: 250 }, aspectRatio: 1 },
            async decodedText => {
                if (phoneScanBusy || phoneAttendanceScanner !== scanner) return;
                phoneScanBusy = true;
                try { scanner.pause(true); } catch {}
                setPhoneAttendanceStatus('QR detected. Sending attendance scan…');
                const { error } = await window.ironGrindSupabase.rpc('submit_mobile_attendance_scan', {
                    p_session_id: sessionId,
                    p_token: token,
                    p_qr_payload: decodedText.trim()
                });
                if (phoneAttendanceScanner !== scanner) return;
                if (error) {
                    setPhoneAttendanceStatus(error.message?.includes('expired')
                        ? 'This pairing has expired. Create a new Phone Camera session on the admin page.'
                        : `Could not send the scan: ${error.message}`, true);
                    if (error.message?.includes('expired')) {
                        await stopPhoneAttendanceScanner();
                        return;
                    }
                } else {
                    setPhoneAttendanceStatus('Scan sent. Ready for the next member.');
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
        setPhoneAttendanceStatus('Camera is on. Point it at a member QR code.');
    } catch (error) {
        phoneAttendanceScanner = null;
        setPhoneAttendanceStatus(error?.name === 'NotAllowedError'
            ? 'Camera permission was denied. Allow camera access in your browser and reload this page.'
            : `Could not start the camera: ${error.message || 'Check camera permissions.'}`, true);
        try { scanner.clear(); } catch {}
    }
}

async function stopPhoneAttendanceScanner() {
    const scanner = phoneAttendanceScanner;
    phoneAttendanceScanner = null;
    phoneScanBusy = false;
    if (!scanner) return;
    try { await scanner.stop(); } catch {}
    try { scanner.clear(); } catch {}
    setPhoneAttendanceStatus('Camera stopped. You can close this page.');
}

window.addEventListener('pagehide', () => {
    const scanner = phoneAttendanceScanner;
    phoneAttendanceScanner = null;
    if (scanner) scanner.stop().catch(() => {});
});

startPhoneAttendanceScanner();
