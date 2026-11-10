import { createClient } from '@supabase/supabase-js';
const headers={'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization, x-client-info, apikey, content-type','Access-Control-Allow-Methods':'POST, OPTIONS'};
const reply=(body:unknown,status=200)=>new Response(JSON.stringify(body),{status,headers:{...headers,'Content-Type':'application/json','Cache-Control':'no-store'}});
Deno.serve(async request=>{
 if(request.method==='OPTIONS')return new Response('ok',{headers});
 if(request.method!=='POST')return reply({error:'Method not allowed.'},405);
 try{
  const url=Deno.env.get('SUPABASE_URL')!,anon=Deno.env.get('SUPABASE_ANON_KEY')!,service=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
  if(!url||!anon||!service)return reply({error:'Device security is unavailable.'},503);
  const authorization=request.headers.get('Authorization')||'';
  const client=createClient(url,anon,{global:{headers:{Authorization:authorization}},auth:{persistSession:false,autoRefreshToken:false}});
  const {data:{user},error:identityError}=await client.auth.getUser();
  if(identityError||!user)return reply({error:'Sign in again.'},401);
  // getUser validates this signed token with Auth before any claim is used.
  const token=authorization.replace(/^Bearer\s+/i,'');
  const encoded=token.split('.')[1];const padded=encoded.replace(/-/g,'+').replace(/_/g,'/');
  const claims=JSON.parse(atob(padded));
  if(claims.sub!==user.id||typeof claims.session_id!=='string')return reply({error:'Invalid session.'},401);
  const raw=await request.text();if(raw.length>8192)return reply({error:'Request too large.'},400);
  const body=JSON.parse(raw);
  const admin=createClient(url,service,{auth:{persistSession:false,autoRefreshToken:false}});
  if(body.action==='challenge'){
   const {data,error}=await admin.rpc('create_admin_device_challenge',{p_user:user.id,p_session:claims.session_id,p_device:body.deviceId,p_scope:body.scope,p_key:body.publicKey});
   if(error)return reply({error:'Could not prepare device verification. Check that device-trust setup is deployed.'},403);
   return reply(data);
  }
  if(body.action!=='complete')return reply({error:'Unsupported action.'},400);
  const {data:challenge,error}=await admin.rpc('get_admin_device_challenge',{p_user:user.id,p_session:claims.session_id});
  if(error||!challenge)return reply({error:'Device verification expired. Cancel and sign in again.'},403);
  if(typeof body.signature!=='string'||body.signature.length>256)return reply({error:'Invalid device proof.'},403);
  const key=await crypto.subtle.importKey('jwk',challenge.public_key,{name:'ECDSA',namedCurve:'P-256'},false,['verify']);
  const signature=Uint8Array.from(atob(body.signature),character=>character.charCodeAt(0));
  if(!await crypto.subtle.verify({name:'ECDSA',hash:'SHA-256'},key,signature,new TextEncoder().encode(challenge.message)))return reply({error:'Device proof was not accepted.'},403);
  const freshMfa=claims.aal==='aal2'&&Array.isArray(claims.amr)&&claims.amr.some((entry:{method?:string;timestamp?:number})=>entry.method==='totp'&&typeof entry.timestamp==='number'&&entry.timestamp>=Math.floor(Number(challenge.issued_at))-1);
  const result=await admin.rpc('finish_admin_device_login',{p_user:user.id,p_session:claims.session_id,p_challenge:challenge.message,p_mfa:freshMfa,p_label:typeof body.label==='string'?body.label.slice(0,180):'Browser'});
  if(result.error)return reply({error:result.error.message==='ADMIN_APPROVAL_REQUIRED'?'Approval is required from your current trusted device. Keep it open and try again.':result.error.message==='ADMIN_MFA_REQUIRED'?'Authenticator verification is required to register this device.':'Could not complete device registration. Cancel and sign in again.'},403);
  return reply({authorized:true});
 }catch{return reply({error:'Device verification could not complete. Check your connection and sign in again.'},400);}
});
