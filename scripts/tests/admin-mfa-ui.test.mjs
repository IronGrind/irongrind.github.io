import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import test from 'node:test';
const source=fs.readFileSync('assets/js/admin-mfa.js','utf8');
function fixture(required=true,level='aal1',enroll=false) {
 const nodes=new Map(); let dialog; const calls=[];
 const node=key=>{if(!nodes.has(key)) nodes.set(key,{value:'123456',disabled:false,hidden:true,focus(){},setAttribute(){},querySelector:selector=>node(key+selector),addEventListener(name,fn){this[name]=fn;},close(){},remove(){this.removed=true;},showModal(){}});return nodes.get(key);};
 const context=vm.createContext({window:{},document:{createElement(){dialog=node('dialog');dialog.querySelector=selector=>node(selector);return dialog;},body:{append(){}}}});
 let verified=false;
 const client={rpc:async()=>({data:required}),auth:{mfa:{
  getAuthenticatorAssuranceLevel:async()=>({data:{currentLevel:verified?'aal2':level}}),
  listFactors:async()=>({data:{totp:enroll?[]:[{id:'factor',status:'verified'}],all:[]}}),
  enroll:async()=>({data:{id:'factor',totp:{qr_code:'data:image/svg+xml,example',secret:'private-setup-key'}}}),
  challengeAndVerify:async args=>{calls.push(args);verified=true;return {};}
 }}};
 vm.runInContext(source,context);
 return {client,run:()=>context.window.requireAdminMfa(client),node,calls,dialog:()=>dialog};
}
const settle=()=>new Promise(resolve=>setImmediate(resolve));
test('staff/member accounts bypass MFA prompt and verified admins do not repeat it',async()=>{
 for(const f of [fixture(false),fixture(true,'aal2')]){await f.run();assert.equal(f.dialog(),undefined);}
});
test('administrator cannot complete gate before verification and code is checked with Auth',async()=>{
 const f=fixture();let completed=false;const pending=f.run().then(()=>{completed=true;});await settle();
 assert.equal(completed,false);await f.node('form').onsubmit({preventDefault(){}});await pending;
 assert.equal(f.calls[0].factorId,'factor');assert.equal(f.calls[0].code,'123456');assert.ok(f.dialog().removed);
});
test('first setup displays enrollment data only inside the temporary dialog',async()=>{
 const f=fixture(true,'aal1',true);const pending=f.run();await settle();
 assert.equal(f.node('.admin-mfa-enrollmentinput').value,'private-setup-key');
 assert.equal(f.node('.admin-mfa-enrollment').hidden,false);
 await f.node('form').onsubmit({preventDefault(){}});await pending;assert.ok(f.dialog().removed);
});
test('cancel refuses completion; bootstrap failure fails closed',async()=>{
 const f=fixture();const pending=f.run();await settle();
 f.node('button[type="button"]').onclick();await assert.rejects(pending,/cancelled/);assert.equal(f.calls.length,0);
 const other=fixture();other.client.rpc=async()=>({error:{message:'offline'}});await assert.rejects(other.run(),/Could not check/);
});
test('missing deployed MFA function explains incomplete setup instead of suggesting refresh',async()=>{
 const f=fixture();f.client.rpc=async()=>({error:{code:'PGRST202'}});
 await assert.rejects(f.run(),/setup is incomplete/);assert.equal(f.dialog(),undefined);
});
test('rejected code reports safe service reason and keeps the login gate closed',async()=>{
 const f=fixture();f.client.auth.mfa.challengeAndVerify=async()=>({error:{code:'mfa_verification_failed'}});
 const pending=f.run();await settle();await f.node('form').onsubmit({preventDefault(){}});
 assert.match(f.node('[role="status"]').textContent,/mfa_verification_failed/);
 assert.match(f.node('[role="status"]').textContent,/IronGrind authenticator entry/);
 assert.equal(f.dialog().removed,undefined);
 f.node('button[type="button"]').onclick();await assert.rejects(pending,/cancelled/);
});
test('post-verification session error is not described as an incorrect code',async()=>{
 const f=fixture();let calls=0;
 f.client.auth.mfa.getAuthenticatorAssuranceLevel=async()=>++calls===1?{data:{currentLevel:'aal1'}}:{error:{code:'session_expired'}};
 const pending=f.run();await settle();await f.node('form').onsubmit({preventDefault(){}});
 assert.match(f.node('[role="status"]').textContent,/session could not be confirmed/);
 assert.doesNotMatch(f.node('[role="status"]').textContent,/code does not match/);
 assert.equal(f.dialog().removed,undefined);
 f.node('button[type="button"]').onclick();await assert.rejects(pending,/cancelled/);
});
