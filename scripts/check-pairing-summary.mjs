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
assert.match(elements.get('phonePairingLimitSummary').textContent,/0 \/ 2 paired.*2 pending/);
paired=true;
await context.refreshPairedAttendancePhones(true);
assert.match(elements.get('phonePairingLimitSummary').textContent,/1 \/ 2 paired.*0 pending/);
assert.equal(elements.get('pairedPhonesCount').textContent,'1');
assert.equal(elements.get('pendingPhonePairingsCount').textContent,'0');
assert.match(elements.get('pairedPhonesList').innerHTML,/Reno 13F 5G/);
let resolve;release=new Promise(r=>resolve=r);
const refresh=context.refreshPairedAttendancePhones(true);
await context.refreshPairedAttendancePhones(true);
assert.equal(vm.runInContext('pairedPhoneListRefreshBusy',context),true,'Guard stays active through the entire refresh');
resolve();await refresh;assert.equal(vm.runInContext('pairedPhoneListRefreshBusy',context),false);
console.log('Passed: paired/pending summary updates with the device list, and overlapping refreshes are prevented.');
