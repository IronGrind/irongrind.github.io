import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
const source=fs.readFileSync('assets/js/admin.js','utf8');
const elements=new Map(['pairedPhonesList','pairedPhonesCount','phonePairingLimitSummary','pendingPhonePairingsList','pendingPhonePairingsCount','activePhoneSessionCount'].map(id=>[id,{textContent:'',innerHTML:''}]));
let paired=false;let release;
const context=vm.createContext({document:{getElementById:id=>elements.get(id)},console,Date,escapeHTML:String,applyPhonePairingCapacityState(){}});
context.window=context;
context.ironGrindSupabase={rpc:async name=>{
 if(release)await release;
 if(name==='list_admin_mobile_attendance_devices')return{data:paired?[{session_id:'phone',paired:true,paired_at:'2026-11-08T11:48:00Z',device:'Reno 13F 5G'}]:[],error:null};
 if(name==='get_mobile_attendance_pairing_settings')return{data:{paired_count:paired?1:0,pending_count:paired?0:2,active_count:paired?1:2,max_pairs:2},error:null};
 return{data:paired?[]:[{session_id:'pending',created_at:'2026-11-08T11:48:00Z'}],error:null};
}};
vm.runInContext('let pairedPhoneListRefreshBusy=false;let pairedPhoneListLastRefreshAt=0;let activeMobileAttendanceSessionId="phone";',context);
for(const name of ['renderPhonePairingSettings','refreshPairedAttendancePhones']){
 const start=source.search(new RegExp(`(?:async )?function ${name}\\(`));
 const end=source.slice(start+1).search(/\n(?:async )?function /);
 vm.runInContext(end<0?source.slice(start):source.slice(start,start+1+end),context);
}
await context.refreshPairedAttendancePhones(true);
assert.equal(elements.get('phonePairingLimitSummary').textContent,'0 phones paired · 2 QRs reserved · 0 slots available');
paired=true;
await context.refreshPairedAttendancePhones(true);
assert.equal(elements.get('phonePairingLimitSummary').textContent,'1 phone paired · 0 QRs reserved · 1 slot available');
context.renderPhonePairingSettings({paired_count:1,pending_count:1,active_count:2,max_pairs:2});
assert.equal(elements.get('phonePairingLimitSummary').textContent,'1 phone paired · 1 QR reserved · 0 slots available');
assert.equal(elements.get('pairedPhonesCount').textContent,'1');
assert.equal(elements.get('pendingPhonePairingsCount').textContent,'0');
assert.match(elements.get('pairedPhonesList').innerHTML,/Reno 13F 5G/);
let resolve;release=new Promise(r=>resolve=r);
const refresh=context.refreshPairedAttendancePhones(true);
await context.refreshPairedAttendancePhones(true);
assert.equal(vm.runInContext('pairedPhoneListRefreshBusy',context),true,'Guard stays active through the entire refresh');
resolve();await refresh;assert.equal(vm.runInContext('pairedPhoneListRefreshBusy',context),false);
console.log('Passed: paired/pending summary updates with the device list, and overlapping refreshes are prevented.');
vm.runInContext('let phonePairingWasAtDeviceLimit=false;let phonePairQrManuallyHidden=false;',context);
const makeNode=()=>({dataset:{},disabled:false,innerHTML:'',textContent:'',classes:new Map(),classList:{toggle(name,on){this.owner.classes.set(name,on);}},setAttribute(){}});
for(const id of ['phonePairQr','phonePairQrVisibility','phonePairCapacityMessage','createPhonePairingQrButton','phonePairStatus']){
 const node=makeNode();node.classList.owner=node;elements.set(id,node);
}
const start=source.indexOf('function applyPhonePairingCapacityState(');
const end=source.indexOf('\nfunction ',start+1);
vm.runInContext(source.slice(start,end),context);
const qr=elements.get('phonePairQr');qr.dataset.pairingState='pending';
context.applyPhonePairingCapacityState({paired_count:1,pending_count:1,active_count:2,max_pairs:2});
assert.equal(qr.classes.get('hidden'),false,'A reserved QR remains scannable when all slots are used');
assert.equal(elements.get('createPhonePairingQrButton').classes.get('hidden'),true,'No third slot can be created');
assert.equal(elements.get('phonePairQrVisibility').disabled,false);
qr.dataset.pairingState='unavailable';
context.applyPhonePairingCapacityState({paired_count:2,pending_count:0,active_count:2,max_pairs:2});
assert.equal(qr.classes.get('hidden'),true,'Claimed or expired QR cannot be reused');
console.log('Passed: full capacity blocks new QRs while keeping an existing pending QR visible for completion.');
