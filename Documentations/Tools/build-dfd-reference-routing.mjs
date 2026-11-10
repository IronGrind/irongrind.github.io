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
const W=3600,H=3100,shapes=[],edges=[];
const label=(s,x,y,size=19,anchor='middle')=>'<text x="'+x+'" y="'+y+'" text-anchor="'+anchor+'" font-size="'+size+'">'+esc(s)+'</text>';
const actors=new Map();
['Member / Applicant','Administrator','Authorized Staff'].forEach((name,i)=>{
 const a={x:60,y:450+i*900,w:380,h:140,ports:0};actors.set(name,a);
 shapes.push('<rect x="'+a.x+'" y="'+a.y+'" width="380" height="140" fill="#d5e2f5" stroke="#111" stroke-width="2"/>',label(name,a.x+190,a.y+76,23));
});
const stores=new Map();for(const p of processes)for(const s of p.Stores)if(!stores.has(s[0]))stores.set(s[0],{name:s[1],id:s[0],ports:0});
let k=0;for(const id of ['D0','D1','D14','D15','D16','D17','D2','D3','D8','D4','D10','D11','D13','D5','D6','D7','D9']){
 const s=stores.get(id);
 Object.assign(s,{x:2880,y:155+k++*160,w:660,h:70});
 shapes.push('<path d="M3540 '+s.y+'H2880V'+(s.y+70)+'H3540 M2950 '+s.y+'V'+(s.y+70)+'" fill="#d5e2f5" stroke="#111" stroke-width="2"/>',label(s.id,2915,s.y+43,20),label(s.name,2970,s.y+43,19,'start'));
}
let count=0;
const routes=[];
function drawRoute(points,name,lx,ly){
 const d=points.map(([x,y],i)=>(i?'L':'M')+x+' '+y).join(' ');
 edges.push('<g class="connector"><path d="'+d+'" fill="none" stroke="white" stroke-width="8"/><path d="'+d+'" fill="none" stroke="#111" stroke-width="2.4" stroke-linejoin="round" marker-end="url(#arrow)"/>'+label(name,lx,ly,18)+'</g>');
}
function route(points,name,lx,ly,destination){
 routes.push({points,name,lx,ly,destination});count++;
}
function renderSharedFlows(){
 const groups=new Map();
 for(const r of routes){
  const key=JSON.stringify([r.destination,r.name.trim().toLowerCase()]);
  if(!groups.has(key))groups.set(key,[]);groups.get(key).push(r);
 }
 for(const group of groups.values()){
  const first=group[0];
  if(group.length===1){drawRoute(first.points,first.name,first.lx,first.ly);continue;}
  const end=first.points.at(-1),rail=first.points[1][0];
  const starts=group.map(r=>r.points[0]);
  const ys=[end[1],...starts.map(p=>p[1])],lo=Math.min(...ys),hi=Math.max(...ys);
  const branches=starts.map(([x,y])=>'M'+x+' '+y+'H'+rail).join(' ');
  const trunk='M'+rail+' '+lo+'V'+hi;
  const common='M'+rail+' '+end[1]+'H'+end[0];
  const d=branches+' '+trunk;
  edges.push('<g class="shared-flow" data-branches="'+group.length+'"><path d="'+d+' '+common+'" fill="none" stroke="white" stroke-width="8"/><path d="'+d+'" fill="none" stroke="#111" stroke-width="2.4"/><path d="'+common+'" fill="none" stroke="#111" stroke-width="2.4" marker-end="url(#arrow)"/>'+starts.map(([,y])=>'<circle cx="'+rail+'" cy="'+y+'" r="4" fill="#111"/>').join('')+label(first.name,(rail+end[0])/2,end[1]-12,18)+'</g>');
 }
 return groups.size;
}
let ai=0,si=0;
processes.forEach((p,i)=>{
 const x=1190,y=150+i*315,w=660,h=245;
 shapes.push('<g id="process-'+(i+1)+'"><rect x="'+x+'" y="'+y+'" width="'+w+'" height="'+h+'" rx="16" fill="white" stroke="#111" stroke-width="2.5"/><path d="M'+(x+16)+' '+y+'H'+(x+w-16)+'Q'+(x+w)+' '+y+' '+(x+w)+' '+(y+16)+'V'+(y+48)+'H'+x+'V'+(y+16)+'Q'+x+' '+y+' '+(x+16)+' '+y+'" fill="#d5e2f5"/><path d="M'+x+' '+(y+48)+'H'+(x+w)+'" stroke="#111"/>'+label(p.Id,x+w/2,y+32,22)+label(p.Name,x+w/2,y+145,24)+'</g>');
 (actorFlows[i]||[]).forEach((a,j)=>{
  const actor=actors.get(a[0]);const sy=actor.y+15+(actor.ports++)*8,ty=y+70+j*35,lane=500+(ai++)*24;
  route([[actor.x+actor.w,sy],[lane,sy],[lane,ty],[x,ty]],a[1],1010,ty-10,'process:'+p.Id);
 });
 p.Stores.forEach((row,j)=>{
  const s=stores.get(row[0]),py=y+61+j*25,sy=s.y+10+(s.ports++)*7,lane=2180+(si++)*11;
  const pts=[[x+w,py],[lane,py],[lane,sy],[s.x,sy]];
  route(row[2]?pts:pts.toReversed(),row[2]||row[3],2010,py-5,row[2]?'store:'+s.id:'process:'+p.Id);
 });
});
const sharedCount=renderSharedFlows();
const svg='<?xml version="1.0" encoding="UTF-8"?><svg xmlns="http://www.w3.org/2000/svg" width="'+W+'" height="'+H+'" viewBox="0 0 '+W+' '+H+'"><defs><marker id="arrow" markerWidth="11" markerHeight="10" refX="10" refY="5" orient="auto" markerUnits="userSpaceOnUse"><path d="M0 0L11 5L0 10Z" fill="#111"/></marker></defs><style>text{font-family:Arial,sans-serif;fill:#111;paint-order:stroke;stroke:white;stroke-width:5;stroke-linejoin:round}path{stroke-linecap:round}</style><rect width="100%" height="100%" fill="white"/>'+label('Iron Grind - Gane-Sarson Level 1 DFD',60,50,32,'start')+label('Same-named flows to the same destination share one line | dots mark branches; gaps mark crossings',60,87,21,'start')+edges.join('')+shapes.join('')+label('Simplified view: initiating inputs/writes shown; return flows for two-way pairs remain in the source model.',60,3055,20,'start')+'</svg>';
if(count!==68)throw Error('Unexpected flow count '+count);
fs.writeFileSync(path.join(root,'03-dfd-complete-gane-sarson.svg'),svg);
console.log('Generated shared-node layout: 9 processes, '+stores.size+' stores, 3 entities, '+count+' source flows in '+sharedCount+' connector groups.');
