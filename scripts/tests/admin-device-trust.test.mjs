import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import { stripTypeScriptTypes } from 'node:module';
import { webcrypto } from 'node:crypto';
import test from 'node:test';
const browserSource=fs.readFileSync('assets/js/admin-device-trust.js','utf8');
const edgeSource=stripTypeScriptTypes(fs.readFileSync('supabase/functions/admin-device-trust/index.ts','utf8').replace(/^import .*\n/,''));
test('browser private key is non-extractable but its proof verifies with the public key',async()=>{
 const pair=await webcrypto.subtle.generateKey({name:'ECDSA',namedCurve:'P-256'},false,['sign','verify']);
 await assert.rejects(webcrypto.subtle.exportKey('jwk',pair.privateKey));
 const signature=await webcrypto.subtle.sign({name:'ECDSA',hash:'SHA-256'},pair.privateKey,new TextEncoder().encode('challenge'));
 assert.ok(await webcrypto.subtle.verify({name:'ECDSA',hash:'SHA-256'},pair.publicKey,signature,new TextEncoder().encode('challenge')));
});
async function browser(reusable){
 const pair=await webcrypto.subtle.generateKey({name:'ECDSA',namedCurve:'P-256'},false,['sign','verify']),calls=[];
 const window={isSecureContext:true};
 const context=vm.createContext({window,crypto:webcrypto,TextEncoder,btoa,navigator:{userAgent:'Test browser'}});
 vm.runInContext(browserSource,context);
 window.readAdminDeviceKey=async()=>({deviceId:'device',privateKey:pair.privateKey,publicKey:await webcrypto.subtle.exportKey('jwk',pair.publicKey)});
 window.waitForAdminDeviceApproval=async()=>{calls.push('approval');return true;};
 window.verifyAdminAuthenticator=async(_,force)=>{assert.equal(force,true);calls.push('mfa');};
 const client={rpc:async()=>({data:true}),functions:{invoke:async(_,args)=>{calls.push(args.body.action);return {data:args.body.action==='challenge'?{message:'signed-message',reusable}:{authorized:true}};}}};
 return {window,client,calls};
}
test('trusted browser skips approval and MFA; untrusted browser completes both before registration',async()=>{
 const trusted=await browser(true);await trusted.window.requireAdminMfa(trusted.client);assert.deepEqual(trusted.calls,['challenge','complete']);
 const fresh=await browser(false);await fresh.window.requireAdminMfa(fresh.client);assert.deepEqual(fresh.calls,['challenge','approval','mfa','complete']);
});
test('failed MFA never attempts registration or transfer',async()=>{
 const f=await browser(false);f.window.verifyAdminAuthenticator=async()=>{throw Error('cancelled');};
 await assert.rejects(f.window.requireAdminMfa(f.client),/cancelled/);assert.deepEqual(f.calls,['challenge','approval']);
});
async function edge(signatureValid=true,freshMfa=true){
 const pair=await webcrypto.subtle.generateKey({name:'ECDSA',namedCurve:'P-256'},false,['sign','verify']);
 const message='server-session-bound-random-challenge',now=Math.floor(Date.now()/1000),calls=[];
 const proof=await webcrypto.subtle.sign({name:'ECDSA',hash:'SHA-256'},pair.privateKey,new TextEncoder().encode(signatureValid?message:'different-message'));
 const claims={sub:'user',session_id:'session',aal:'aal2',amr:[{method:'totp',timestamp:freshMfa?now:now-3600}]};
 const token='header.'+Buffer.from(JSON.stringify(claims)).toString('base64url')+'.signature';
 const admin={rpc:async(name,args)=>{calls.push([name,args]);if(name==='get_admin_device_challenge')return {data:{message,public_key:await webcrypto.subtle.exportKey('jwk',pair.publicKey),issued_at:now}};return args.p_mfa?{}:{error:{message:'ADMIN_MFA_REQUIRED'}};}};
 const client={auth:{getUser:async()=>({data:{user:{id:'user'}}})}};
 let handler;vm.runInNewContext(edgeSource,{Response,TextEncoder,Uint8Array,atob,crypto:webcrypto,Deno:{env:{get:key=>key},serve:fn=>{handler=fn;}},createClient:(_,key)=>key==='SUPABASE_SERVICE_ROLE_KEY'?admin:client});
 return {calls,response:await handler(new Request('https://example.invalid',{method:'POST',headers:{Authorization:'Bearer '+token},body:JSON.stringify({action:'complete',signature:Buffer.from(proof).toString('base64')})}))};
}
test('Edge Function rejects invalid signatures before calling trusted completion',async()=>{
 const f=await edge(false);assert.equal(f.response.status,403);assert.equal(f.calls.length,1);
});
test('Edge Function accepts signed proof with fresh MFA and does not treat old MFA as fresh',async()=>{
 const valid=await edge();assert.equal(valid.response.status,200);assert.equal(valid.calls[1][1].p_mfa,true);
 const stale=await edge(true,false);assert.equal(stale.response.status,403);assert.equal(stale.calls[1][1].p_mfa,false);
});
