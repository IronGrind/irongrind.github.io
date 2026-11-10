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



const W=9200,H=3100,groups=[],mapping=[],segments=[];
const esc=s=>String(s).replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;');
const text=(s,x,y,size=20)=>'<text x="'+x+'" y="'+y+'" text-anchor="middle" font-size="'+size+'">'+esc(s)+'</text>';
const expected=processes.reduce((n,p,i)=>n+p.Stores.reduce((m,s)=>m+Number(!!s[2])+Number(!!s[3]),0)+actorFlows[i].reduce((m,a)=>m+Number(!!a[1])+Number(!!a[2]),0),0);
const refCounts=new Map();processes.forEach(p=>p.Stores.forEach(s=>refCounts.set(s[0],(refCounts.get(s[0])||0)+1)));
processes.forEach((p,i)=>{
 const ox=70+(i%3)*3050,oy=220+Math.floor(i/3)*950;
 let shapes='',labels='';const routes=[];
 function flow(points,name,source,destination,lx,ly){
  const r={points,name,source,destination,parts:[]};
  for(let j=1;j<points.length;j++){
   const a=points[j-1],b=points[j];const part={a,b,h:a[1]===b[1],jumps:[],route:r};r.parts.push(part);segments.push(part);
  }
  routes.push(r);mapping.push({process:p.Id,source,destination,name});labels+=text(name,lx,ly,16);
 }
 const x=1000,y=260,w=650,h=360;
 shapes+='<g id="process-'+(i+1)+'"><rect x="1000" y="260" width="650" height="360" rx="18" fill="white" stroke="#111" stroke-width="2.5"/><path d="M1018 260H1632Q1650 260 1650 278V310H1000V278Q1000 260 1018 260" fill="#d5e2f5"/><path d="M1000 310H1650" stroke="#111"/>'+text(p.Id,1325,294,25)+text(p.Name,1325,450,25)+'</g>';
 actorFlows[i].forEach((a,j)=>{
  const ay=440-(actorFlows[i].length*210)/2+j*210;
  shapes+='<rect x="20" y="'+ay+'" width="350" height="100" fill="#d5e2f5" stroke="#111" stroke-width="2"/>'+text(a[0],195,ay+56,22);
  [a[1],a[2]].forEach((name,d)=>{
   if(!name)return;const sy=ay+30.4+d*38,py=330+j*90+d*34,lane=530+j*50+d*20;
   const points=[[370,sy],[lane,sy],[lane,py],[1000,py]];
   flow(d?points.toReversed():points,name,d?'process:'+p.Id:'actor:'+a[0],d?'actor:'+a[0]:'process:'+p.Id,820,py-10);
  });
 });
 p.Stores.forEach((s,j)=>{
  const sy=440-p.Stores.length*110/2+j*110;
  shapes+='<path d="M2970 '+sy+'H2350V'+(sy+80)+'H2970 M2425 '+sy+'V'+(sy+80)+'" fill="white" stroke="#111" stroke-width="2"/>'+text(s[0],2387,sy+47,21)+text(s[1],2695,sy+47,20);
  [s[2],s[3]].forEach((name,d)=>{
   if(!name)return;const py=320+j*42+d*18,ty=sy+25.3+d*32,lane=1750+j*48+d*20;
   const points=[[1650,py],[lane,py],[lane,ty],[2350,ty]];
   flow(d?points.toReversed():points,name,d?'store:'+s[0]:'process:'+p.Id,d?'process:'+p.Id:'store:'+s[0],2180,ty-9);
  });
 });
 groups.push({ox,oy,shapes,labels,routes});
});
let crossings=0,overlaps=0;
// Each local cluster is independent geometrically; identifiers preserve one logical model.
for(const group of groups){
 const parts=group.routes.flatMap(r=>r.parts);
 for(let i=0;i<parts.length;i++)for(let j=i+1;j<parts.length;j++){
  const a=parts[i],b=parts[j];if(a.route===b.route)continue;
  if(a.h===b.h){const axis=a.h?0:1,o=1-axis;if(Math.abs(a.a[o]-b.a[o])<.01&&Math.min(Math.max(a.a[axis],a.b[axis]),Math.max(b.a[axis],b.b[axis]))-Math.max(Math.min(a.a[axis],a.b[axis]),Math.min(b.a[axis],b.b[axis]))>.01)overlaps++;continue;}
  const h=a.h?a:b,v=a.h?b:a,x=v.a[0],y=h.a[1];
  if(x>Math.min(h.a[0],h.b[0])+.01&&x<Math.max(h.a[0],h.b[0])-.01&&y>=Math.min(v.a[1],v.b[1])&&y<=Math.max(v.a[1],v.b[1])){h.jumps.push(x);crossings++;}
 }
}
let jumps=0;const output=[];
for(const group of groups){
 let lines='',overlays='';
 for(const r of group.routes){let d='M'+r.points[0].join(' ');
  for(const seg of r.parts){const dir=Math.sign(seg.b[0]-seg.a[0]);const xs=[...new Set(seg.jumps)].sort((a,b)=>(a-b)*dir);
   xs.forEach((x,i)=>{const before=i?Math.abs(x-xs[i-1]):Math.abs(x-seg.a[0]),after=i+1<xs.length?Math.abs(xs[i+1]-x):Math.abs(seg.b[0]-x);const radius=Math.min(5,before/2.5,after/2.5),y=seg.a[1];
    d+='L'+(x-dir*radius)+' '+y+'Q'+x+' '+(y-radius*2)+' '+(x+dir*radius)+' '+y;
    const arc='M'+(x-dir*(radius+2))+' '+y+'L'+(x-dir*radius)+' '+y+'Q'+x+' '+(y-radius*2)+' '+(x+dir*radius)+' '+y+'L'+(x+dir*(radius+2))+' '+y;
    overlays+='<path d="'+arc+'" fill="none" stroke="white" stroke-width="6"/><path d="'+arc+'" fill="none" stroke="#111" stroke-width="2"/>';jumps++;
   });d+='L'+seg.b.join(' ');
  }
  lines+='<path class="data-flow" d="'+d+'" fill="none" stroke="#111" stroke-width="2" marker-end="url(#arrow)"/>';
 }
 output.push('<g transform="translate('+group.ox+' '+group.oy+')">'+lines+overlays+group.shapes+group.labels+'</g>');
}
if(mapping.length!==expected||overlaps)throw Error('Flow or overlap audit failed '+mapping.length+' / '+expected+' overlaps '+overlaps);
const svg='<?xml version="1.0" encoding="UTF-8"?><svg xmlns="http://www.w3.org/2000/svg" width="'+W+'" height="'+H+'" viewBox="0 0 '+W+' '+H+'"><defs><marker id="arrow" markerWidth="11" markerHeight="10" refX="10" refY="5" orient="auto" markerUnits="userSpaceOnUse"><path d="M0 0L11 5L0 10Z" fill="#111"/></marker></defs><style>text{font-family:Arial,sans-serif;fill:#111;paint-order:stroke;stroke:white;stroke-width:4}path{stroke-linejoin:round}</style><rect width="100%" height="100%" fill="white"/>'+text('Iron Grind - Complete Level 1 DFD - Gane-Sarson',W/2,65,40)+text('One diagram: read processes 1-3 across the first row, 4-6 across the second, 7-9 across the third.',W/2,112,25)+text('Repeated D identifiers/table names and actor names are references to the SAME stores and entities, not additional tables or actors.',W/2,152,25)+output.join('')+text('Single-headed arrows show data direction. Curved jumps indicate crossings without connections. Documented source-model coverage: 108 flows, 9 processes, 17 unique stores, 3 unique entities.',W/2,H-30,23)+'</svg>';
fs.writeFileSync(path.join(root,'03-dfd-complete-gane-sarson.svg'),svg);
fs.writeFileSync(path.join(root,'_Sources/dfd-local-reference-audit.json'),JSON.stringify({processes:9,uniqueStores:refCounts.size,uniqueActors:3,flows:mapping.length,crossings,jumps,unrelatedOverlaps:overlaps,mapping},null,2)+'\n');
console.log(JSON.stringify({processes:9,uniqueStores:refCounts.size,uniqueActors:3,flows:mapping.length,crossings,jumps,unrelatedOverlaps:overlaps}));
