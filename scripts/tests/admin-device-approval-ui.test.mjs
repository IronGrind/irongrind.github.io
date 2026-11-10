import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import test from 'node:test';
const source=fs.readFileSync('assets/js/admin-device-approval.js','utf8');
const settle=()=>new Promise(resolve=>setImmediate(resolve));
function fixture(rpc){
 const timers=[],created=[];
 function element(){
  const children=new Map();const buttons=[{dataset:{decision:'deny'}},{dataset:{decision:'approve'}}];
  return {dataset:{},setAttribute(){},showModal(){},close(){},remove(){this.removed=true;},
   addEventListener(name,fn){this[name]=fn;},
   querySelector(selector){if(!children.has(selector))children.set(selector,{textContent:''});return children.get(selector);},
   querySelectorAll(){return buttons;}};
 }
 const client={rpc};
 const context=vm.createContext({navigator:{userAgent:'Test browser'},console,Date,
  document:{body:{append(){}},createElement(){const el=element();created.push(el);return el;}},
  window:{location:{pathname:'/index.html'},addEventListener(){},removeEventListener(){}},
  setInterval(fn){timers.push(fn);return timers.length;},clearInterval(){}
 });
 vm.runInContext(source,context);
 return {client,window:context.window,created,timers};
}
test('no active approver chooses MFA rather than granting access',async()=>{
 const f=fixture(async()=>({data:{status:'mfa_required'}}));
 assert.equal(await f.window.waitForAdminDeviceApproval(f.client,'dashboard'),false);
 assert.equal(f.created.length,0);
});
test('requesting browser waits until exact server approval',async()=>{
 let count=0;const f=fixture(async()=>({data:{status:++count===1?'pending':'approved',expires_at:'2099-01-01'}}));
 let completed=false;const pending=f.window.waitForAdminDeviceApproval(f.client,'dashboard').then(value=>{completed=true;return value;});
 await settle();assert.equal(completed,false);await f.timers[0]();
 assert.equal(await pending,true);assert.ok(f.created[0].removed);
});
test('denial rejects login and authenticator fallback cancels the pending request',async()=>{
 let count=0;const denied=fixture(async()=>({data:{status:++count===1?'pending':'denied',expires_at:'2099-01-01'}}));
 const failure=denied.window.waitForAdminDeviceApproval(denied.client,'dashboard');await settle();
 const rejected=assert.rejects(failure,/denied/);await denied.timers[0]();await rejected;
 const calls=[];const fallback=fixture(async(name,args)=>{calls.push([name,args]);return name==='cancel_admin_login_approval'?{}:{data:{status:'pending',expires_at:'2099-01-01'}};});
 const pending=fallback.window.waitForAdminDeviceApproval(fallback.client,'attendance');await settle();
 await fallback.created[0].querySelector('[data-action="mfa"]').onclick();assert.equal(await pending,false);
 assert.equal(calls[1][0],'cancel_admin_login_approval');assert.equal(calls[1][1].p_scope,'attendance');
});
test('active-device notification uses safe text and sends the selected decision',async()=>{
 const calls=[];const f=fixture(async(name,args)=>{calls.push([name,args]);return name==='list_admin_login_approvals'?{data:[{id:'request-id',device_label:'<script>unsafe</script>',session_scope:'dashboard',requested_at:'2026-11-10T00:00:00Z'}]}:{};});
 f.window.startAdminApprovalNotifications(f.client);await settle();
 const panel=f.created[0];assert.equal(panel.querySelector('.approval-device').textContent,'<script>unsafe</script>');
 assert.doesNotMatch(panel.innerHTML,/<script>unsafe/);
 await panel.querySelectorAll()[1].onclick();
 assert.equal(calls[1][0],'decide_admin_login_approval');assert.equal(calls[1][1].p_request_id,'request-id');assert.equal(calls[1][1].p_approve,true);
 f.window.stopAdminApprovalNotifications(f.client);assert.equal(f.client.__stopApprovalNotifications,null);
});
