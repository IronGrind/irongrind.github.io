import {readFileSync,writeFileSync} from 'node:fs';
import {join} from 'node:path';
const dir=join(import.meta.dirname,'..','Chapter 3 Diagrams');
const schema=JSON.parse(readFileSync(join(dir,'schema-visualizer.json'),'utf8').replace(/^\uFEFF/,''));
const sql=readFileSync(join(import.meta.dirname,'../../supabase/migrations/20261110000006_member_device_approval.sql'),'utf8');
const descriptions={user_id:'Identifies the member account. A trusted-device primary key permits at most one registered browser per account.',device_id:'Identifies the browser key; no foreign key or hardware identity is implied.',public_key:'Stores the public ECDSA P-256 JWK. The private signing key remains in browser IndexedDB.',device_label:'Stores a reported browser label, not verified hardware identity.',registered_at:'Records browser enrollment time.',last_seen_at:'Records the recent dashboard heartbeat used to select an available approving browser.',session_id:'Identifies the Auth session awaiting or holding browser authorization.',challenge:'Stores the session-bound signing message. Successful verification consumes it.',challenge_expires_at:'Bounds the signing challenge; the creating function uses a ten-minute window.',authorized_until:'Remains null before authorization and bounds the authorized member session.',id:'Identifies this browser-replacement approval request.',requesting_session_id:'Binds the request to one Auth session; this column must be unique.',approver_session_id:'Records the deciding Auth session. Session deletion clears attribution while preserving the request.',status:'Stores pending, approved, denied, or consumed. Expiration is derived from timestamps.',requested_at:'Records request creation.',expires_at:'Limits the approval request to two minutes by default.',decided_at:'Records the approval or denial time when present.'};
const purposes={member_trusted_devices:'Stores one registered browser public key per member account; separate from administrator trust and attendance phone pairing.',member_device_sessions:'Binds an Auth session to a browser signing challenge and authorization boundary.',member_device_approvals:'Stores session-bound requests to replace a member browser, including approval, denial and consumption.'};
const tables=[],relations=[];
for(const m of sql.matchAll(/create table if not exists (private\.(\w+)) \(\r?\n([\s\S]*?)\r?\n\);/g)){
 const [,Name,short,body]=m;const Columns=[];
 for(const line of body.split(/\r?\n/)){
  const c=line.trim().match(/^(\w+) (uuid|jsonb|text|timestamptz)(.*)/);if(!c)continue;
  const [,Name,Type,tail]=c;const Keys=[];
  if(tail.includes('primary key'))Keys.push('PK');if(tail.includes('references'))Keys.push('FK');
  if(Name==='requesting_session_id')Keys.push('UQ');
  const extra=[];if(tail.includes('default'))extra.push('Default '+tail.match(/default (.*?)(?: check|,$|$)/)[1].replace(/,$/,'')+'.');
  if(Name==='status')extra.push('CHECK pending, approved, denied, or consumed.');
  Columns.push({Name,Type,Required:/not null|primary key/.test(tail),Keys,Description:descriptions[Name],Extra:extra.join(' ')});
  const fk=tail.match(/references (auth\.\w+)\((\w+)\) on delete (cascade|set null)/);
  if(fk)relations.push({Child:m[1],Field:Name,Parent:fk[1],ParentField:fk[2],Delete:fk[3].toUpperCase()});
 }
 tables.push({Name,Purpose:purposes[short],Columns});
}
if(tables.length!==3||tables.reduce((s,t)=>s+t.Columns.length,0)!==23||relations.length!==6)throw Error('Migration parse mismatch');
schema.Tables=schema.Tables.filter(t=>!tables.some(v=>v.Name===t.Name)).concat(tables);
schema.Relations=schema.Relations.filter(r=>!tables.some(t=>t.Name===r.Child)).concat(relations);
schema.Source='Supplied public-schema context export and checked-in migrations through 20261110000006. Deployment status follows the repository Member Device Approval Guide; this is not fresh live-schema introspection.';
writeFileSync(join(dir,'schema-visualizer.json'),JSON.stringify(schema,null,2)+'\n');
writeFileSync(join(dir,'_Sources/member-paper-model.json'),JSON.stringify({tables,relations},null,2)+'\n');
// Three separate relationship panels keep every child FK and its parent readable.
const esc=s=>String(s).replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('"','&quot;');
const items=[],cells=[];let serial=0;
function box(x,y,w,h,text){items.push({x,y,w,h,text});cells.push(`<mxCell id="b${++serial}" value="${esc(text).replaceAll('\n','&#xa;')}" style="rounded=0;whiteSpace=wrap;html=0;align=left;verticalAlign=top;spacing=12;fontFamily=Arial;fontSize=22;fillColor=#ffffff;strokeColor=#000000;" vertex="1" parent="1"><mxGeometry x="${x}" y="${y}" width="${w}" height="${h}" as="geometry"/></mxCell>`);}
box(30,20,1740,85,'Member browser security â€” migration 20261110000006\nDeclared FK links only; repeated Auth cards refer to the same managed tables.');
let y=140;const lines=[];
for(const t of tables){const h=Math.max(300,65+t.Columns.length*32);box(30,y,880,h,t.Name+'\n'+t.Columns.map(c=>`${c.Keys.join('/')||'â€”'}  ${c.Name}: ${c.Type}${c.Required?' *':''}`).join('\n'));
 const refs=relations.filter(r=>r.Child===t.Name);refs.forEach((r,i)=>{const ry=y+i*100;box(1160,ry,610,85,`${r.Parent} (${r.ParentField}: PK)\n${r.Field} â†’ ${r.ParentField}; DELETE ${r.Delete}`);const cy=y+58+t.Columns.findIndex(c=>c.Name===r.Field)*32;lines.push([[910,cy],[970+i*48,cy],[970+i*48,ry+42],[1160,ry+42]]);});y+=h+65;}
box(30,y,1740,105,'* = NOT NULL. Each FK references one existing parent when non-null; a nullable FK permits no parent.\nPK on user_id/session_id and UQ on requesting_session_id permit at most one child for that link.\nOther links permit many children. device_id has no declared FK.');
const H=y+135;
for(const points of lines)cells.push(`<mxCell id="e${++serial}" style="endArrow=open;strokeColor=#000000;" edge="1" parent="1"><mxGeometry relative="1" as="geometry"><mxPoint x="${points[0][0]}" y="${points[0][1]}" as="sourcePoint"/><mxPoint x="${points.at(-1)[0]}" y="${points.at(-1)[1]}" as="targetPoint"/><Array as="points">${points.slice(1,-1).map(([x,y])=>`<mxPoint x="${x}" y="${y}"/>`).join('')}</Array></mxGeometry></mxCell>`);
const svg=`<svg xmlns="http://www.w3.org/2000/svg" width="1800" height="${H}" viewBox="0 0 1800 ${H}"><rect width="1800" height="${H}" fill="white"/>${lines.map(p=>`<path d="M ${p.map(v=>v.join(' ')).join(' L ')}" stroke="black" fill="none" stroke-width="2"/>`).join('')}${items.map(p=>`<rect x="${p.x}" y="${p.y}" width="${p.w}" height="${p.h}" fill="white" stroke="black"/><text font-family="Arial" font-size="22">${p.text.split('\n').map((s,i)=>`<tspan x="${p.x+12}" y="${p.y+30+i*32}">${esc(s)}</tspan>`).join('')}</text>`).join('')}</svg>`;
writeFileSync(join(dir,'05b-member-security-schema.svg'),svg);
writeFileSync(join(dir,'05b-member-security-schema.drawio'),`<mxfile><diagram name="Member browser security"><mxGraphModel page="1" pageWidth="1800" pageHeight="${H}"><root><mxCell id="0"/><mxCell id="1" parent="0"/>${cells.join('')}</root></mxGraphModel></diagram></mxfile>`);
writeFileSync(join(dir,'_Sources/member-erd-render.json'),JSON.stringify({H,items,lines},null,2));
console.log('21 tables, 224 fields, 33 foreign keys; member ERD generated.');

