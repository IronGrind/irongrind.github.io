// Read-only hosted checks. Uses a fresh headless Edge profile; never signs in.
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import {spawn} from 'node:child_process';
import {createHash} from 'node:crypto';
const base='https://irongrind-github-io.vercel.app';
const folder='Documentations/Review Evidence';
fs.mkdirSync(folder,{recursive:true});
const report={completedAt:null,base,scope:'Unauthenticated hosted page, asset, browser and API checks; no account or operational writes.',assets:[],pages:[],api:[]};
const sha=b=>createHash('sha256').update(b).digest('hex');
const normalize=b=>b.toString('utf8').replace(/^\uFEFF/,'').replaceAll('\r\n','\n').trimEnd();
const files=fs.readdirSync('.').filter(f=>f.endsWith('.html')).concat(['attendance-phone-sw.js','attendance-app.webmanifest'],...['assets/js','assets/css'].map(dir=>fs.existsSync(dir)?fs.readdirSync(dir).filter(f=>/\.(js|css)$/.test(f)).map(f=>`${dir}/${f}`):[]));
for(const file of files){
 try{const r=await fetch(`${base}/${file}`,{signal:AbortSignal.timeout(20000)});const bytes=Buffer.from(await r.arrayBuffer()),local=fs.readFileSync(file);report.assets.push({file,status:r.status,matchesLocal:r.ok&&sha(bytes)===sha(local),matchesNormalized:r.ok&&normalize(bytes)===normalize(local)});}
 catch(e){report.assets.push({file,error:e.message,matchesLocal:false});}
}
const config=fs.readFileSync('assets/js/supabase-client.js','utf8');
const url=config.match(/IRON_GRIND_SUPABASE_URL = '([^']+)'/)[1],key=config.match(/IRON_GRIND_SUPABASE_PUBLISHABLE_KEY = '([^']+)'/)[1];
for(const name of ['admin-device-trust','member-device-trust','admin-create-member','admin-create-staff','verify-store-password']){
 try{const r=await fetch(`${url}/functions/v1/${name}`,{method:'POST',headers:{apikey:key,'Content-Type':'application/json'},body:'{}',signal:AbortSignal.timeout(20000)});report.api.push({name,status:r.status,unauthenticatedDenied:[401,403].includes(r.status)});}
 catch(e){report.api.push({name,error:e.message});}
}
// Empty registration is rejected before validation can reach account creation.
try{const r=await fetch(`${url}/functions/v1/member-registration`,{method:'POST',headers:{apikey:key,'Content-Type':'application/json'},body:'{}',signal:AbortSignal.timeout(20000)});report.api.push({name:'member-registration empty input',status:r.status,invalidInputDenied:r.status===400});}catch(e){report.api.push({name:'member-registration',error:e.message});}
const profile=fs.mkdtempSync(path.join(os.tmpdir(),'ig-readiness-browser-'));
const browser=spawn('C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',['--headless=new','--disable-gpu','--no-first-run','--no-default-browser-check','--remote-debugging-port=0',`--user-data-dir=${profile}`,'about:blank'],{windowsHide:true,stdio:'ignore'});
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
const pending=new Map();let socket,id=0,active=null;
try{
 const portFile=path.join(profile,'DevToolsActivePort');
 for(let i=0;i<100&&!fs.existsSync(portFile);i++)await sleep(200);
 if(!fs.existsSync(portFile))throw Error('Headless Edge debugging endpoint did not start');
 const port=fs.readFileSync(portFile,'utf8').split('\n')[0];
 const tabs=await (await fetch(`http://127.0.0.1:${port}/json/list`)).json();
 socket=new WebSocket(tabs.find(t=>t.type==='page').webSocketDebuggerUrl);
 await new Promise((resolve,reject)=>{socket.onopen=resolve;socket.onerror=reject;});
 socket.onmessage=event=>{const m=JSON.parse(event.data);if(m.id){const p=pending.get(m.id);if(p){pending.delete(m.id);m.error?p.reject(Error(m.error.message)):p.resolve(m.result);}}else if(active){
  if(m.method==='Runtime.exceptionThrown')active.errors.push(m.params.exceptionDetails.exception?.description||m.params.exceptionDetails.text);
  if(m.method==='Network.loadingFailed'&&!m.params.canceled)active.networkFailures.push({type:m.params.type,error:m.params.errorText});
  if(m.method==='Network.responseReceived'&&m.params.response.status>=400){const r=m.params.response;active.httpErrors.push({url:r.url.split('?')[0],status:r.status});}
 }};
 const send=(method,params={})=>new Promise((resolve,reject)=>{const key=++id;const timer=setTimeout(()=>{pending.delete(key);reject(Error(`CDP timeout: ${method}`));},25000);pending.set(key,{resolve:r=>{clearTimeout(timer);resolve(r);},reject:e=>{clearTimeout(timer);reject(e);}});socket.send(JSON.stringify({id:key,method,params}));});
 const evaluate=async expression=>(await send('Runtime.evaluate',{expression,returnByValue:true,awaitPromise:true})).result?.value;
 await send('Runtime.enable');await send('Page.enable');await send('Network.enable');
 for(const mobile of [false,true]){
  await send('Emulation.setDeviceMetricsOverride',{width:mobile?390:1440,height:mobile?844:1000,deviceScaleFactor:1,mobile});
  for(const file of ['index.html','register.html','reset-password.html','attendance-phone.html','admin.html','staff.html','customer.html']){
   active={file,viewport:mobile?'mobile':'desktop',errors:[],networkFailures:[],httpErrors:[]};report.pages.push(active);
   await send('Page.navigate',{url:`${base}/${file}`});await sleep(3000);
   Object.assign(active,await evaluate(`({url:location.href,title:document.title,ready:document.readyState,theme:document.documentElement.dataset.dashboardTheme,overflow:document.documentElement.scrollWidth>innerWidth+1,hasClient:!!window.ironGrindSupabase})`));
   if(['admin.html','staff.html','customer.html'].includes(file))active.redirectedToLogin=/\/(?:index\.html)?(?:[?#]|$)/.test(new URL(active.url).pathname);
   if(file==='index.html'){
    active.themeToggle=await evaluate(`(async()=>{window.setDashboardTheme?.('light');window.showForgotPassword?.();const m=document.getElementById('forgotPasswordModal');return {theme:document.documentElement.dataset.dashboardTheme,modalOpened:!!m&&!m.classList.contains('hidden')};})()`);
   }else if(file==='register.html')active.themeToggle=await evaluate(`(()=>{window.setDashboardTheme?.('light');return {theme:document.documentElement.dataset.dashboardTheme};})()`);
   if(['index.html','register.html'].includes(file)){const shot=await send('Page.captureScreenshot',{format:'png',captureBeyondViewport:false});fs.writeFileSync(`${folder}/Hosted ${file.replace('.html','')} ${active.viewport}.png`,Buffer.from(shot.data,'base64'));}
   console.log(`Browser ${active.viewport} ${file}: ${active.errors.length} JS exceptions; ${active.httpErrors.length} HTTP errors; overflow=${active.overflow}`);
   active=null;
  }
 }
 await send('Browser.close');
}catch(e){report.browserError=e.message;}finally{socket?.close();browser.kill();report.completedAt=new Date().toISOString();fs.writeFileSync(`${folder}/Hosted Readiness Results.json`,JSON.stringify(report,null,2)+'\n');}
console.log(JSON.stringify({assets:report.assets.length,matchingAssets:report.assets.filter(a=>a.matchesLocal).length,api:report.api,pages:report.pages.length,browserError:report.browserError}));
if(report.browserError||report.assets.some(a=>!a.matchesLocal&&!a.matchesNormalized)||report.pages.some(p=>p.errors.length||p.httpErrors.length||p.overflow||p.redirectedToLogin===false)||report.api.some(a=>!(a.unauthenticatedDenied||a.invalidInputDenied)))process.exitCode=1;
