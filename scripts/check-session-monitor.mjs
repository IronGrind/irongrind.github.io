import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
const source=fs.readFileSync('assets/js/supabase-client.js','utf8');
async function setup(path='/staff.html') {
  const intervals=[]; const redirects=[]; const signouts=[]; const removed=[];
  let result={data:true,error:null}; let session={access_token:'current'};
  const client={auth:{ getSession:async()=>({data:{session}}),onAuthStateChange:()=>({data:{subscription:{unsubscribe(){}}}}),signOut:async options=>{signouts.push(options);session=null;} },rpc:async()=>result};
  const context=vm.createContext({document:{body:{classList:{contains:()=>false}},hidden:false,addEventListener(){}},navigator:{onLine:true},setInterval:fn=>intervals.push(fn),setTimeout,console,localStorage:{removeItem:k=>removed.push(k)},sessionStorage:{removeItem:k=>removed.push(k)}});
  context.window=context; context.location={pathname:path,replace:url=>redirects.push(url)};
  context.addEventListener=()=>{}; context.supabase={createClient:()=>client};
  vm.runInContext(source,context); await new Promise(setImmediate);
  return {context,client,intervals,redirects,signouts,removed,setResult:r=>result=r};
}
const app=await setup(); assert.equal(app.redirects.length,0);
app.setResult({data:null,error:{message:'Network unavailable'}}); await app.intervals[0]();
assert.equal(app.signouts.length,0,'Network failure is not proof of replacement');
app.setResult({data:false,error:null}); await app.intervals[0]();
assert.equal(app.signouts[0].scope,'local','An old device never revokes the new device');
assert.equal(app.redirects[0],'index.html?auth=replaced');
assert.equal(app.removed.length,2);
await app.intervals[0](); assert.equal(app.signouts.length,1,'Only one replacement action');
const offline=await setup(); offline.context.navigator.onLine=false; offline.setResult({data:false,error:null}); await offline.intervals[0](); assert.equal(offline.signouts.length,0);
for(const path of ['/index.html','/register.html','/reset-password.html']) assert.equal((await setup(path)).intervals.length,0,'Public/recovery pages do not redirect while signing in');
console.log('Passed: active session retained, replacement clears local session and redirects, network failures do not log users out, and public/recovery pages are excluded.');
