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
