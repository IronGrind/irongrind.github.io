import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../Chapter 3 Diagrams');
const readJson = file => JSON.parse(fs.readFileSync(file, 'utf8').replace(/^\uFEFF/, ''));
const processes = readJson(path.join(root, '03-gane-sarson-flows.json'));
const actorFlows = readJson(path.join(root, '_Sources/dfd-actor-flows.json'));
// Action labels preserve the nine established functional boundaries.
const processLabels = [
 'Verify login and authorize access',
 'Submit and review applications',
 'Manage profiles and member accounts',
 'Submit and review renewal requests',
 'Record QR scans and retrieve visits',
 'Update stock and retrieve products',
 'Record sales and sale items',
 'Compile and export selected reports',
 'Filter and view activity records'
];
processes.forEach((process, index) => { process.Name = processLabels[index]; });


// Do not group report stores into a range; each store gets its own symbol and flow.
const reportStores = [
  ['D2', 'membership_applications', '', 'Application report records'],
  ['D3', 'members', '', 'Member report records'],
  ['D4', 'attendance', '', 'Attendance report records'],
  ['D5', 'products', '', 'Product report records'],
  ['D6', 'sales', '', 'Sales report records'],
  ['D7', 'sale_items', '', 'Sale item report records'],
  ['D8', 'membership_history', '', 'Membership history records']
];
processes.find(process => process.Id === '8.0').Stores = reportStores;
// Resolve stores to exact tables in the documented database baseline.
const schema = readJson(path.join(root, 'schema-visualizer.json'));
const tableNames = new Set(schema.Tables.map(table => table.Name));
tableNames.add('auth.users');
const storeTables = {
 D0:'auth.users', D1:'public.profiles', D2:'public.membership_applications',
 D3:'public.members', D4:'public.attendance', D5:'public.products',
 D6:'public.sales', D7:'public.sale_items', D8:'public.membership_history',
 D9:'public.activity_logs', D10:'public.mobile_attendance_pairing_policy',
 D11:'public.mobile_attendance_scan_sessions', D13:'private.attendance_scan_requests',
 D14:'private.account_sessions', D15:'private.admin_login_approvals',
 D16:'private.admin_trusted_devices', D17:'private.admin_device_sessions'
};
for (const process of processes) {
 const seen = new Set();
 process.Stores = process.Stores.filter(store => {
  if (seen.has(store[0])) return false;
  seen.add(store[0]); return true;
 }).map(store => {
  const name = storeTables[store[0]];
  if (!tableNames.has(name)) throw new Error('Unverified DFD table: ' + store[0]);
  return [store[0], name.split('.').at(-1), store[2], store[3]];
 });
}


const esc=s=>String(s).replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;');
const W=6600,H=5300,shapes=[],edges=[];
const label=(s,x,y,size=19,anchor='middle')=>'<text x="'+x+'" y="'+y+'" text-anchor="'+anchor+'" font-size="'+size+'">'+esc(s)+'</text>';
const actors=new Map();
['Member / Applicant','Administrator','Authorized Staff'].forEach((name,i)=>{
 const a={x:60,y:550+i*1700,w:480,h:420,ports:0};actors.set(name,a);
 shapes.push('<rect x="'+a.x+'" y="'+a.y+'" width="480" height="420" fill="#d5e2f5" stroke="#111" stroke-width="2"/>',label(name,a.x+240,a.y+175,23));
});
const stores=new Map();for(const p of processes)for(const s of p.Stores)if(!stores.has(s[0]))stores.set(s[0],{name:s[1],id:s[0],ports:0});
let k=0;for(const id of ['D0','D1','D14','D15','D16','D17','D2','D3','D8','D4','D10','D11','D13','D5','D6','D7','D9']){
 const s=stores.get(id);
 Object.assign(s,{x:5840,y:180+k++*285,w:700,h:160});
 shapes.push('<path d="M6540 '+s.y+'H5840V'+(s.y+160)+'H6540 M5920 '+s.y+'V'+(s.y+160)+'" fill="#d5e2f5" stroke="#111" stroke-width="2"/>',label(s.id,5880,s.y+88,22),label(s.name,5940,s.y+88,22,'start'));
}
let count=0;
const routes=[];
const drawings=[];
function drawRoute(points,name,lx,ly){
 drawings.push({paths:[{points,arrow:true}],text:label(name,lx,ly,18),branches:1,dots:[]});
}
// Level 1 logical data categories. Detailed subflows and role scopes are
// preserved in the audit mapping; a shared category does not grant access.
const storeCategories={
 D0:['Account and session updates','Identity and session data'],
 D1:['Profile updates','Permitted profile and role data'],
 D2:['Application and renewal updates','Application and renewal records'],
 D3:['Member and membership updates','Permitted member data'],
 D4:['Attendance updates','Permitted attendance records'],
 D5:['Product and stock updates','Permitted product data'],
 D6:['Sales transactions','Permitted sales records'],
 D7:['Sale-item records','Permitted sale-item data'],
 D8:['Membership change events','Membership history data'],
 D9:['Activity events','Filtered activity records'],
 D10:['Pairing policy updates','Pairing policy data'],
 D11:['Paired-device updates','Paired-device authorization'],
 D13:['Scan results','Previous scan results'],
 D14:['Session scope updates','Session ownership data'],
 D15:['Login approval updates','Pending login approvals'],
 D16:['Trusted public keys','Device trust state'],
 D17:['Device session updates','Authorized device sessions']
};
const actorCategories=[
 ['Sign-in details','Role-specific access results'],
 ['Application submissions and decisions','Role-scoped application results'],
 ['Permitted account operations','Role-scoped account results'],
 ['Renewal submissions and decisions','Role-scoped renewal results'],
 ['Permitted attendance requests','Role-scoped attendance results'],
 ['Permitted product requests','Role-scoped product results'],
 ['Permitted sales requests','Role-scoped sales results'],
 ['Report criteria','Report preview and export'],
 ['Activity filters','Filtered activity results']
];
function route(points,name,lx,ly,destination){
 const start=points[0];let source;
 if(start[0]===1950||start[0]===2690)source='process:'+processes[Math.floor((start[1]-180)/550)].Id;
 else if(start[0]===540)source='actor:'+ [...actors].find(([,a])=>start[1]>=a.y&&start[1]<=a.y+a.h)[0];
 else source='store:'+ [...stores].find(([,a])=>start[1]>=a.y&&start[1]<=a.y+a.h)[0];
 let canonical;
 if(destination.startsWith('store:'))canonical=storeCategories[destination.slice(6)][0];
 else if(source.startsWith('store:'))canonical=storeCategories[source.slice(6)][1];
 else if(source.startsWith('actor:'))canonical=actorCategories[parseInt(destination.slice(8),10)-1][0];
 else canonical=actorCategories[parseInt(source.slice(8),10)-1][1];
 routes.push({points,name:canonical,originalName:name,lx,ly,source,destination});count++;
}
function renderSharedFlows(){
 const remaining=new Set(routes);const grouped=[];
 while(remaining.size){
  const candidates=new Map();
  for(const r of remaining)for(const side of ['source','destination']){
   const key=JSON.stringify([side,r[side],r.name.trim().toLowerCase()]);
   if(!candidates.has(key))candidates.set(key,{side,routes:[]});candidates.get(key).routes.push(r);
  }
  const best=[...candidates.values()].sort((a,b)=>b.routes.length-a.routes.length)[0];
  best.routes.forEach(r=>remaining.delete(r));grouped.push(best);
 }
 for(const {routes:group,side} of grouped){
  const first=group[0];
  if(group.length===1){drawRoute(first.points,first.name,first.lx,first.ly);continue;}
  const outward=side==='source';
  const common=outward?first.points[0]:first.points.at(-1);
  const ends=group.map(r=>outward?r.points.at(-1):r.points[0]);
  const rail=first.points[1][0];
  const ys=[common[1],...ends.map(p=>p[1])],lo=Math.min(...ys),hi=Math.max(...ys);
  const paths=ends.map(([x,y])=>({points:outward?[[rail,y],[x,y]]:[[x,y],[rail,y]],arrow:outward}));
  paths.push({points:[[rail,lo],[rail,hi]],arrow:false},{points:outward?[common,[rail,common[1]]]:[[rail,common[1]],common],arrow:!outward});
  const lx=common[0]===1950?1730:common[0]===5840?5520:common[0]===540?1730:2940;
  drawings.push({paths,text:label(first.name,lx,common[1]-12,18),branches:group.length,dots:ends.map(([,y])=>[rail,y])});
 }
 return grouped.length;
}
// Add a geometric bridge to every horizontal crossing of an unrelated route.
function renderJumps(){
 const segments=[];
 drawings.forEach((g,group)=>g.paths.forEach(path=>{
  path.segments=[];
  for(let i=1;i<path.points.length;i++){
   const a=path.points[i-1],b=path.points[i];
   if(a[0]===b[0]&&a[1]===b[1])continue;
   const seg={a,b,group,h:a[1]===b[1],jumps:[]};path.segments.push(seg);segments.push(seg);
  }
 }));
 let crossings=0,overlaps=0;
 for(let i=0;i<segments.length;i++)for(let j=i+1;j<segments.length;j++){
  const a=segments[i],b=segments[j];if(a.group===b.group)continue;
  if(a.h===b.h){
   const axis=a.h?0:1,other=1-axis;
   if(Math.abs(a.a[other]-b.a[other])<0.01&&Math.min(Math.max(a.a[axis],a.b[axis]),Math.max(b.a[axis],b.b[axis]))-Math.max(Math.min(a.a[axis],a.b[axis]),Math.min(b.a[axis],b.b[axis]))>0.01)overlaps++;
   continue;
  }
  const h=a.h?a:b,v=a.h?b:a,x=v.a[0],y=h.a[1];
  if(x>Math.min(h.a[0],h.b[0])+0.01&&x<Math.max(h.a[0],h.b[0])-0.01&&y>=Math.min(v.a[1],v.b[1])-0.01&&y<=Math.max(v.a[1],v.b[1])+0.01){h.jumps.push(x);crossings++;}
 }
 let bridges=0;
 const jumpOverlays=[];
 for(const g of drawings){
  let paths='';
  for(const p of g.paths){
   let d='M'+p.points[0].join(' ');
   for(const seg of p.segments){
    const dir=Math.sign(seg.b[0]-seg.a[0]);
    const xs=[...new Set(seg.jumps)].sort((a,b)=>(a-b)*dir);
    xs.forEach((x,i)=>{
     const before=i?Math.abs(x-xs[i-1]):Math.abs(x-seg.a[0]);
     const after=i+1<xs.length?Math.abs(xs[i+1]-x):Math.abs(seg.b[0]-x);
     const r=Math.min(7,before/2.5,after/2.5);
     const tail=Math.min(3,r/2);
     const arc='M'+(x-dir*(r+tail))+' '+seg.a[1]+'L'+(x-dir*r)+' '+seg.a[1]+'Q'+x+' '+(seg.a[1]-r*2)+' '+(x+dir*r)+' '+seg.a[1]+'L'+(x+dir*(r+tail))+' '+seg.a[1];
     d+='L'+(x-dir*r)+' '+seg.a[1]+'Q'+x+' '+(seg.a[1]-r*2)+' '+(x+dir*r)+' '+seg.a[1];
     jumpOverlays.push('<path d="'+arc+'" fill="none" stroke="white" stroke-width="7"/><path d="'+arc+'" fill="none" stroke="#111" stroke-width="2.4"/>');bridges++;
    });
    d+='L'+seg.b.join(' ');
   }
   paths+='<path d="'+d+'" fill="none" stroke="white" stroke-width="7"/><path class="flow-line" d="'+d+'" fill="none" stroke="#111" stroke-width="2.4"'+(p.arrow?' marker-end="url(#arrow)"':'')+'/>';
  }
  edges.push('<g class="'+(g.branches>1?'shared-flow':'connector')+'" data-branches="'+g.branches+'">'+paths+g.dots.map(([x,y])=>'<circle cx="'+x+'" cy="'+y+'" r="4" fill="#111"/>').join('')+g.text+'</g>');
 }
 edges.push('<g class="crossing-jumps">'+jumpOverlays.join('')+'</g>');
 edges.push('<g class="flow-labels">'+drawings.map(g=>g.text).join('')+'</g>');
 if(overlaps)throw Error('Unrelated collinear overlaps: '+overlaps);
 console.log('Routing audit: '+crossings+' crossings, '+bridges+' bridge jumps, zero unrelated collinear overlaps.');
 return {crossings,bridges,overlaps};
}
let ai=0,si=0;
processes.forEach((p,i)=>{
 const x=1950,y=180+i*550,w=740,h=440;
 shapes.push('<g id="process-'+(i+1)+'"><rect x="'+x+'" y="'+y+'" width="'+w+'" height="'+h+'" rx="16" fill="white" stroke="#111" stroke-width="2.5"/><path d="M'+(x+16)+' '+y+'H'+(x+w-16)+'Q'+(x+w)+' '+y+' '+(x+w)+' '+(y+16)+'V'+(y+48)+'H'+x+'V'+(y+16)+'Q'+x+' '+y+' '+(x+16)+' '+y+'" fill="#d5e2f5"/><path d="M'+x+' '+(y+48)+'H'+(x+w)+'" stroke="#111"/>'+label(p.Id,x+w/2,y+32,22)+label(p.Name,x+w/2,y+245,26)+'</g>');
 (actorFlows[i]||[]).forEach((a,j)=>{
  const actor=actors.get(a[0]);
  for(const [direction,name] of [['input',a[1]],['output',a[2]]]){
   if(!name)continue;
   const sy=actor.y+20.4+(actor.ports++)*20;
   const ty=y+100+j*95+(direction==='output'?40:0),lane=630+(ai++)*24;
   const pts=[[actor.x+actor.w,sy],[lane,sy],[lane,ty],[x,ty]];
   route(direction==='input'?pts:pts.toReversed(),name,1730,ty-12,direction==='input'?'process:'+p.Id:'actor:'+a[0]);
  }
 });
 p.Stores.forEach((row,j)=>{
  const store=stores.get(row[0]);
  for(const [direction,name] of [['write',row[2]],['read',row[3]]]){
   if(!name)continue;
   const py=y+75+j*48+(direction==='read'?23:0),sy=store.y+15.3+(store.ports++)*13;
   const lane=3240+(si++)*27;
   const pts=[[x+w,py],[lane,py],[lane,sy],[store.x,sy]];
   route(direction==='write'?pts:pts.toReversed(),name,2940,py-8,direction==='write'?'store:'+store.id:'process:'+p.Id);
  }
 });
});
// Put short connections near the processes and long runs farther outside.
for(const side of ['actor','store']){
 const ordered=routes.filter(r=>side==='actor'?r.points.some(p=>p[0]===540):r.points.some(p=>p[0]===5840)).sort((a,b)=>Math.abs(a.points[0][1]-a.points.at(-1)[1])-Math.abs(b.points[0][1]-b.points.at(-1)[1]));
 ordered.forEach((r,i)=>{const lane=side==='actor'?1710-i*24:3240+i*27;r.points[1][0]=lane;r.points[2][0]=lane;});
}
const sharedCount=renderSharedFlows();
const routingAudit=renderJumps();
const svg='<?xml version="1.0" encoding="UTF-8"?><svg xmlns="http://www.w3.org/2000/svg" width="'+W+'" height="'+H+'" viewBox="0 0 '+W+' '+H+'"><defs><marker id="arrow" markerWidth="11" markerHeight="10" refX="10" refY="5" orient="auto" markerUnits="userSpaceOnUse"><path d="M0 0L11 5L0 10Z" fill="#111"/></marker></defs><style>text{font-family:Arial,sans-serif;fill:#111;paint-order:stroke;stroke:white;stroke-width:5;stroke-linejoin:round}path{stroke-linecap:round}</style><rect width="100%" height="100%" fill="white"/>'+label('Iron Grind - Gane-Sarson Level 1 DFD',60,50,32,'start')+label('Logical data categories share trunks and branches | dots mark branches; curved jumps mark crossings',60,87,21,'start')+edges.join('')+shapes.join('')+label('Complete directional coverage of the documented DFD source model. Detailed subflows are mapped in the routing audit; role-scoped branches do not grant identical access.',60,5210,22,'start')+'</svg>';
const expected=processes.reduce((n,p,i)=>n+p.Stores.reduce((m,r)=>m+Number(!!r[2])+Number(!!r[3]),0)+(actorFlows[i]||[]).reduce((m,a)=>m+Number(!!a[1])+Number(!!a[2]),0),0);
if(count!==expected)throw Error('Flow coverage mismatch');
fs.writeFileSync(path.join(root,'03-dfd-complete-gane-sarson.svg'),svg);
fs.writeFileSync(path.join(root,'_Sources/dfd-routing-audit.json'),JSON.stringify({processes:processes.length,stores:stores.size,entities:actors.size,representedFlows:count,connectorGroups:sharedCount,...routingAudit,flowMapping:routes.map(({source,destination,originalName,name})=>({source,destination,originalName,displayName:name}))},null,2)+'\n');
console.log('Generated shared-node layout: 9 processes, '+stores.size+' stores, 3 entities, '+count+' source flows in '+sharedCount+' connector groups.');
