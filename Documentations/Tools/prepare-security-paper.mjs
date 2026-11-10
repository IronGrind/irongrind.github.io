import {readFileSync,writeFileSync} from 'node:fs';
import {join} from 'node:path';
const dir=join(import.meta.dirname,'..','Chapter 3 Diagrams');
const load=n=>JSON.parse(readFileSync(join(dir,n),'utf8').replace(/^\uFEFF/,''));
const schema=load('schema-visualizer.json');
const c=(Name,Type,Required,Keys,Description,Extra='')=>({Name,Type,Required,Keys,Description,Extra});
const tables=[{Name:'private.admin_login_approvals',Purpose:'Records session-bound administrator login requests and approval decisions. Approval alone does not authorize the requesting browser; current device proof and fresh TOTP are also required for replacement.',Columns:[
c('id','uuid',true,['PK'],'Identifies the approval request.','Default gen_random_uuid().'),
c('user_id','uuid',true,['FK'],'Identifies the administrator requesting access.'),
c('requesting_session_id','uuid',true,['FK'],'Identifies the Auth session awaiting authorization.','Part of composite UQ (requesting_session_id, session_scope); the pair must be unique, not either column individually.'),
c('approver_session_id','uuid',false,['FK'],'Records the Auth session that decided the request. Deleting that session clears this attribution without deleting the request.'),
c('session_scope','text',true,[],'Separates dashboard login from attendance-scanner login.','CHECK dashboard or attendance. Part of composite UQ (requesting_session_id, session_scope); the pair must be unique, not either column individually.'),
c('device_label','text',true,[],'Describes the requesting browser for the approval notification. The request function limits the label to 180 characters; text has no declared character length.'),
c('status','text',true,[],'Records the decision state. Expiration is calculated from timestamps and is not an additional stored status.','Default pending. CHECK pending, approved, denied, or cancelled.'),
c('requested_at','timestamptz',true,[],'Records creation of the request.','Default now().'),
c('expires_at','timestamptz',true,[],'Limits how long the pending request may be decided.','Default now() + interval 2 minutes.'),
c('decided_at','timestamptz',false,[],'Records when approval or denial was recorded.'),
c('approval_expires_at','timestamptz',false,[],'Retains the approval-validity boundary. A valid approval does not replace the current trusted-device and authorized-session checks.'),
c('trusted_device_id','uuid',false,[],'Snapshots the trusted device being replaced. Deliberately not a foreign key: historical requests must survive replacement of the trusted row.')
]},{Name:'private.admin_trusted_devices',Purpose:'Stores one current trusted browser public key per administrator account. Browser trust is fixed at thirty days and is separate from normal account logout and phone-camera pairing.',Columns:[
c('user_id','uuid',true,['PK','FK'],'Identifies the administrator. The primary key permits at most one trusted-browser row per administrator.'),
c('device_id','uuid',true,[],'Identifies the browser key in the application. It is not globally unique and is not a hardware identifier.'),
c('public_key','jsonb',true,[],'Stores the ECDSA P-256 public JWK used to verify device signatures. The private key remains non-extractable in browser IndexedDB.'),
c('device_label','text',true,[],'Stores the descriptive label of the trusted browser.'),
c('registered_at','timestamptz',true,[],'Records registration of the current trusted browser.','Default now().'),
c('expires_at','timestamptz',true,[],'Records the trust expiration set thirty days after registration. Routine reuse does not extend this boundary.'),
c('last_seen_at','timestamptz',true,[],'Records recent browser activity maintained by the security workflow. It does not prove that a physical device is online.','Default now().')
]},{Name:'private.admin_device_sessions',Purpose:'Binds a candidate or authorized administrator Auth session to a browser key, signing challenge and application scope. Unverified candidates cannot access protected application data.',Columns:[
c('session_id','uuid',true,['PK','FK'],'Identifies the Auth session being challenged or authorized.'),
c('user_id','uuid',true,['FK'],'Identifies the administrator associated with the session.'),
c('device_id','uuid',true,[],'Identifies the candidate browser. No foreign key is declared because a candidate may not yet be trusted.'),
c('session_scope','text',true,[],'Identifies the application scope being authorized.','CHECK dashboard or attendance.'),
c('public_key','jsonb',true,[],'Binds the challenge and authorized session to the submitted public key.'),
c('challenge','text',true,[],'Stores the random session-bound signing message. Successful completion consumes the challenge.'),
c('challenge_expires_at','timestamptz',true,[],'Limits the challenge to a ten-minute verification window established by the creation function.'),
c('authorized_until','timestamptz',false,[],'Remains empty before authorization and cannot exceed the current trusted-device expiration after completion.')
]}];
const relations=[['private.admin_login_approvals','user_id','auth.users','CASCADE'],['private.admin_login_approvals','requesting_session_id','auth.sessions','CASCADE'],['private.admin_login_approvals','approver_session_id','auth.sessions','SET NULL'],['private.admin_trusted_devices','user_id','auth.users','CASCADE'],['private.admin_device_sessions','session_id','auth.sessions','CASCADE'],['private.admin_device_sessions','user_id','auth.users','CASCADE']].map(([Child,Field,Parent,Delete])=>({Child,Field,Parent,ParentField:'id',Delete}));
schema.Tables=schema.Tables.filter(t=>!tables.some(v=>v.Name===t.Name)).concat(tables);
schema.Relations=schema.Relations.filter(r=>!tables.some(t=>t.Name===r.Child)).concat(relations);
schema.Source='Author-supplied pgAdmin export and checked-in migrations through 20261110000004; user-supplied CLI output confirms application of migrations 03 and 04. Not a fresh live database introspection.';
if(schema.Tables.length!==18||schema.Tables.reduce((n,t)=>n+t.Columns.length,0)!==201||schema.Relations.length!==27)throw Error('Schema totals mismatch');
writeFileSync(join(dir,'schema-visualizer.json'),JSON.stringify(schema,null,2)+'\n');
writeFileSync(join(dir,'_Sources/security-paper-model.json'),JSON.stringify({tables,relations},null,2)+'\n');
// Common drawing primitives produce matching editable vector and raster versions.
const esc=s=>String(s).replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;').replaceAll('"','&quot;');
function save(stem,W,H,items){
 let serial=1;const cells=[],svg=[];
 for(const p of items){const id='v'+serial++;
 if(p.kind==='store'){svg.push(`<path d="M ${p.x+p.w} ${p.y} H ${p.x} V ${p.y+p.h} H ${p.x+p.w} M ${p.x+64} ${p.y} V ${p.y+p.h}" fill="none" stroke="black" stroke-width="2"/>`);cells.push(`<mxCell id="${id}" value="" style="shape=partialRectangle;top=1;left=1;bottom=1;right=0;fillColor=none;strokeColor=#000000;" vertex="1" parent="1"><mxGeometry x="${p.x}" y="${p.y}" width="${p.w}" height="${p.h}" as="geometry"/></mxCell>`);cells.push(`<mxCell id="${id}sep" style="endArrow=none;" edge="1" parent="1"><mxGeometry relative="1" as="geometry"><mxPoint x="${p.x+64}" y="${p.y}" as="sourcePoint"/><mxPoint x="${p.x+64}" y="${p.y+p.h}" as="targetPoint"/></mxGeometry></mxCell>`);}
 if(p.kind==='box') {svg.push(`<rect x="${p.x}" y="${p.y}" width="${p.w}" height="${p.h}" fill="${p.fill||'white'}" stroke="black" stroke-width="2"/>`);cells.push(`<mxCell id="${id}" value="" style="fillColor=${p.fill||'#ffffff'};strokeColor=#000000;" vertex="1" parent="1"><mxGeometry x="${p.x}" y="${p.y}" width="${p.w}" height="${p.h}" as="geometry"/></mxCell>`);}
 if(p.kind==='text'){svg.push(`<text x="${p.x}" y="${p.y+24}" font-family="Arial" font-size="22">${esc(p.text)}</text>`);cells.push(`<mxCell id="${id}" value="${esc(p.text)}" style="text;html=0;align=left;fontFamily=Arial;fontSize=22;" vertex="1" parent="1"><mxGeometry x="${p.x}" y="${p.y}" width="${p.w||550}" height="32" as="geometry"/></mxCell>`);}
 if(p.kind==='line'){svg.push(`<path d="M ${p.points.map(v=>v.join(' ')).join(' L ')}" fill="none" stroke="${p.color||'black'}" stroke-width="2" ${p.both?'marker-start="url(#arrow)"':''} ${p.arrow?'marker-end="url(#arrow)"':''}/>`);cells.push(`<mxCell id="${id}" style="edgeStyle=segmentEdgeStyle;strokeColor=${p.color||'#000000'};startArrow=${p.both?'block':'none'};endArrow=${p.arrow?'block':'none'};" edge="1" parent="1"><mxGeometry relative="1" as="geometry"><mxPoint x="${p.points[0][0]}" y="${p.points[0][1]}" as="sourcePoint"/><mxPoint x="${p.points.at(-1)[0]}" y="${p.points.at(-1)[1]}" as="targetPoint"/><Array as="points">${p.points.slice(1,-1).map(([x,y])=>`<mxPoint x="${x}" y="${y}"/>`).join('')}</Array></mxGeometry></mxCell>`);}
 }
 writeFileSync(join(dir,stem+'.svg'),`<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}"><defs><marker id="arrow" markerWidth="8" markerHeight="6" refX="8" refY="3" orient="auto-start-reverse"><path d="M0 0 L8 3 L0 6 Z"/></marker></defs><rect width="${W}" height="${H}" fill="white"/>${svg.join('')}</svg>`);
 writeFileSync(join(dir,stem+'.drawio'),`<mxfile host="app.diagrams.net"><diagram name="${stem}"><mxGraphModel page="1" pageWidth="${W}" pageHeight="${H}"><root><mxCell id="0"/><mxCell id="1" parent="0"/>${cells.join('')}</root></mxGraphModel></diagram></mxfile>`);
 writeFileSync(join(dir,'_Sources',stem+'.json'),JSON.stringify({W,H,items},null,2));
}
const box=(x,y,w,h,fill)=>({kind:'box',x,y,w,h,fill}),text=(x,y,text,w)=>({kind:'text',x,y,text,w}),line=(points,arrow=false,both=false)=>({kind:'line',points,arrow,both});
const d=[];
const names=['D15 | private.admin_login_approvals','D16 | private.admin_trusted_devices','D17 | private.admin_device_sessions'];
names.forEach((n,i)=>{const y=65+i*210;d.push({kind:'store',x:25,y,w:470,h:85},text(33,y+26,n.split(' | ')[0]),text(100,y+26,n.split(' | ')[1]),line([[495,y+42],[755,y+42]],true,true),text(505,y-3,['Request / decision','Trusted public key','Challenge / authorization'][i],245));});
d.push(box(755,65,320,505),box(755,65,320,65,'#d5e2f5'),text(875,82,'1.0'),text(810,270,'User Login'),box(1370,255,300,115,'#d5e2f5'),text(1430,294,'Administrator'),line([[1075,310],[1370,310]],true,true),text(1085,224,'Sign-in / approval',280),text(1085,330,'requests and results',280),text(35,630,'Expansion of the security stores used by Process 1.0; D0, D1 and D14 remain in Figure 3.',1600));
save('03a-login-security-stores',1700,700,d);
const e=[];
// Six FK lines end at distinct parent ports; no cross-table shortcuts are invented.
tables.forEach((t,i)=>{const y=25+i*490;const rows=t.Columns.map(c=>`${c.Keys.join('/')}  ${c.Name} : ${c.Type}`);e.push(box(25,y,640,55+rows.length*31),box(25,y,640,46,'#d5e2f5'),text(40,y+9,t.Name));rows.forEach((r,k)=>e.push(text(40,y+51+k*31,r)));});
for(const [name,y] of [['users',45],['sessions',175],['users',515],['sessions',970],['users',1100]])e.push(box(1130,y,360,105),box(1130,y,360,45,'#d5e2f5'),text(1150,y+8,`auth.${name} (reference)`),text(1150,y+58,'PK  id : uuid'));
const routes=[[[665,132],[740,132],[740,115],[1130,115]],[[665,163],[820,163],[820,235],[1130,235]],[[665,194],[760,194],[760,260],[1130,260]],[[665,590],[1130,590]],[[665,1056],[800,1056],[800,1040],[1130,1040]],[[665,1087],[800,1087],[800,1175],[1130,1175]]];
routes.forEach(p=>e.push(line(p)));
e.push(text(30,1450,'Repeated Auth cards reference the same managed tables. Lines show declared FKs; no extra FK is implied.',1470));
save('05a-administrator-security-schema',1530,1510,e);
console.log('Prepared 18 tables / 201 fields / 27 foreign keys and two editable security figures.');
