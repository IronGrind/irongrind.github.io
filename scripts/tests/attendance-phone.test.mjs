import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';
import test from 'node:test';

function app() {
    const elements = new Map();
    const element = id => {
        if (!elements.has(id)) elements.set(id, { hidden: true, disabled: false, value: '', textContent: '', style: {}, classList: { add() {}, remove() {}, toggle() {}, contains() { return false; } } });
        return elements.get(id);
    };
    const storage = () => { const items = new Map(); return { getItem: key => items.get(key) ?? null, setItem: (key, value) => items.set(key, value), removeItem: key => items.delete(key) }; };
    const localStorage = storage();
    const sessionStorage = storage();
    const window = { addEventListener() {}, supabase: { createClient: () => ({}) }, setTimeout() {} };
    const context = vm.createContext({ window, document: { body: element('body'), getElementById: element }, localStorage, sessionStorage,
        IRON_GRIND_SUPABASE_URL: 'https://example.invalid', IRON_GRIND_SUPABASE_PUBLISHABLE_KEY: 'public', console, navigator: {}, crypto: globalThis.crypto });
    const source = readFileSync(new URL('../../assets/js/attendance-phone.js', import.meta.url), 'utf8').replace(/startPhoneAttendanceApp\(\);\s*$/, '');
    vm.runInContext(source, context);
    return { context, element, localStorage, run: code => vm.runInContext(code, context) };
}

test('remembered phone pairing survives a new app instance', () => {
    const first = app();
    first.run("savePhonePairing('session', 'secret', true)");
    const second = app();
    second.localStorage.setItem('ig_remembered_attendance_phone_pairing', first.localStorage.getItem('ig_remembered_attendance_phone_pairing'));
    assert.equal(second.run('readPhonePairing().sessionId'), 'session');
});

test('scanner signs in with website credentials without MFA or website device trust', async () => {
    const fixture = app();
    fixture.element('phoneOperatorId').value = 'owner';
    fixture.element('phoneOperatorPassword').value = 'password';
    fixture.run(`globalThis.calls=[];
        phoneOperatorClient={functions:{invoke:async(name,args)=>{calls.push([name,args.body]);return {data:{session:{access_token:'test'}}};}},
        auth:{setSession:async()=>({}),startAutoRefresh(){},signOut:async()=>({})},
        rpc:async(name)=>{calls.push([name]);return name==='get_attendance_operator'?{data:{id:'owner',full_name:'Owner'}}:{};}};
        window.requireAdminMfa=()=>{throw Error('Scanner must not request MFA');};
        window.waitForScannerLoginApproval=async()=>{calls.push(['scanner-approval']);};
        window.monitorAccountSession=(_,callback,rpc)=>{calls.push([rpc]);};`);
    await fixture.run('signInPhoneOperator({preventDefault(){}})');
    assert.equal(fixture.run('phoneOperator.id'), 'owner');
    assert.equal(fixture.run('calls[0][1].username'), 'owner');
    assert.equal(fixture.run('calls[0][1].password'), 'password');
    assert.equal(fixture.run("calls.map(item=>item[0]).join(',')"), 'admin-username-login,scanner-approval,activate_attendance_session,get_attendance_operator,current_attendance_session_is_active,log_scanner_activity');
    assert.equal(fixture.element('phoneOperatorPassword').value, '');
});

test('refresh restores the existing scanner without a new sign-in or approval', async () => {
    const fixture = app();
    fixture.run(`globalThis.calls=[];
        phoneOperatorClient={auth:{getSession:async()=>({data:{session:{access_token:'same-session'}}}),startAutoRefresh(){}},
        rpc:async name=>{calls.push(name);return name==='current_attendance_session_is_active'?{data:true}:{data:{id:'owner',full_name:'Owner'}};}};
        window.monitorAccountSession=()=>{};window.startScannerApprovalNotifications=()=>{};`);
    assert.equal(await fixture.run('restorePhoneOperatorSession()'), true);
    assert.equal(fixture.run('phoneOperator.id'), 'owner');
    assert.equal(fixture.run("calls.join(',')"), 'current_attendance_session_is_active,get_attendance_operator');
    assert.equal(fixture.element('phoneOperatorSetup').hidden, true);
});

test('refresh with a transient status failure retains the saved scanner session', async () => {
    const fixture = app();
    fixture.run(`globalThis.signedOut=false;phoneOperatorClient={auth:{getSession:async()=>({data:{session:{}}}),signOut:async()=>{signedOut=true;}},rpc:async()=>({error:{message:'Offline'}})};`);
    assert.equal(await fixture.run('restorePhoneOperatorSession()'), true);
    assert.equal(fixture.run('signedOut'), false);
    assert.match(fixture.element('phoneQrStatus').textContent, /saved session was kept/);
});

test('opening another QR to reinstall preserves the existing pairing and token', () => {
    const fixture = app();
    fixture.run("savePhonePairing('existing', 'original-secret', true, '2099-01-01T00:00:00Z')");
    assert.equal(fixture.run("acceptPhonePairingLink('new-qr', 'new-secret')"), false);
    assert.equal(fixture.run('readPhonePairing().sessionId'), 'existing');
    assert.equal(fixture.run('readPhonePairing().token'), 'original-secret');
});

test('first pairing and expired saved pairing accept a fresh QR', () => {
    const fixture = app();
    assert.equal(fixture.run("acceptPhonePairingLink('first', 'secret', '2000-01-01T00:00:00Z')"), true);
    assert.equal(fixture.run("acceptPhonePairingLink('replacement', 'new-secret')"), true);
    assert.equal(fixture.run('readPhonePairing().sessionId'), 'replacement');
});

test('lost connection recovery explains administrator removal and separate installation', () => {
    const fixture = app();
    const message = fixture.run("phonePairingRecoveryMessage({message:'This phone already has an active pairing. End that pairing before using another QR.'})");
    assert.match(message, /removal PIN/);
    assert.match(message, /fresh pairing QR/);
    assert.match(message, /Install attendance app/);
});

test('every camera entry requires operator identity', async () => {
    const fixture = app();
    for (const call of ["startPhonePairingScanner()", "startPhoneMemberScanner('session','token')", 'togglePhoneAttendanceCamera()', 'resumePhoneAttendanceScanner()']) {
        await fixture.run(call);
        assert.equal(fixture.element('phoneOperatorSetup').hidden, false);
        assert.match(fixture.element('phoneQrStatus').textContent, /Sign in/);
    }
});

test('transient validation failure retains saved pairing and does not start pairing camera', async () => {
    const fixture = app();
    fixture.run("phoneOperator = {id:'operator'}; window.isSecureContext = true; navigator.mediaDevices = {getUserMedia(){}}; phonePairingClient.rpc = async () => ({error:{message:'Network unavailable'}}); savePhonePairing('session','secret',true)");
    await fixture.run("startPhoneMemberScanner('session','secret',false)");
    assert.equal(fixture.run('readPhonePairing().token'), 'secret');
    assert.match(fixture.element('phoneQrStatus').textContent, /saved connection was kept/);
});

test('uncertain scan response reuses request id on retry and reports saved outcome', async () => {
    const fixture = app();
    fixture.run(`phoneOperator = {id:'operator',name:'Staff One'}; phoneAttendanceScanner = {pause(){}};
        globalThis.calls = [];
        phoneOperatorClient = {rpc: async (_, args) => { calls.push(args); return calls.length === 1
            ? {error:{message:'Failed to fetch'}} : {data:{action:'check_in', member_name:'Member One'}}; }};`);
    await fixture.run("submitPhoneMemberScan('IRONGRIND|member', phoneAttendanceScanner, {sessionId:'session',token:'secret'})");
    assert.equal(fixture.run('pendingPhoneScan !== null'), true);
    await fixture.run("submitPhoneMemberScan('IRONGRIND|member', phoneAttendanceScanner, {sessionId:'session',token:'secret'})");
    assert.equal(fixture.run('calls[0].p_request_id === calls[1].p_request_id'), true);
    assert.match(fixture.element('phoneQrStatus').textContent, /Member One checked in.*Staff One/);
});
