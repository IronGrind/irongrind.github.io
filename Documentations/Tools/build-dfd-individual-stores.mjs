import {readFileSync,writeFileSync} from 'node:fs';
import {dirname,join} from 'node:path';
import {fileURLToPath} from 'node:url';
const dir=join(dirname(fileURLToPath(import.meta.url)),'..','Chapter 3 Diagrams');
const read=p=>JSON.parse(readFileSync(join(dir,p),'utf8').replace(/^\uFEFF/,''));
const ps=read('03-gane-sarson-flows.json'),actors=read('_Sources/dfd-actor-flows.json');
// Expand the old report-source shorthand into seven individual read stores.
for(const p of ps)p.Stores=p.Stores.flatMap(s=>s[0]==='D2-D8'?['D2','D3','D4','D5','D6','D7','D8'].map(id=>[id,id,'','Report source records']):[s]);
const W=4300,H=3200,svg=[],cells=[],routes=[];let serial=0,represented=0;
const esc=s=>String(s).replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;').replaceAll('"','&quot;');
function vertex(value,style,x,y,w,h){const id='c'+(++serial);cells.push(`<mxCell id="${id}" value="${esc(value)}" style="${style}" vertex="1" parent="1"><mxGeometry x="${x}" y="${y}" width="${w}" height="${h}" as="geometry"/></mxCell>`);return id;}
function text(value,x,y,w,size=27){size=Math.min(size,w/(Math.max(1,value.length)*.55));vertex(value,`text;html=0;whiteSpace=wrap;align=center;verticalAlign=middle;fontFamily=Arial;fontSize=${size};`,x,y,w,42);svg.push(`<text x="${x+w/2}" y="${y+30}" text-anchor="middle" font-family="Arial" font-size="${size}">${esc(value)}</text>`);}
function box(x,y,w,h,round=false){svg.push(`<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="${round?12:0}" fill="white" stroke="black" stroke-width="2"/>`);return vertex('',`rounded=${round?1:0};fillColor=#ffffff;strokeColor=#000000;strokeWidth=2;`,x,y,w,h);}
const definitions=[['D0','auth.users'],['D1','profiles'],['D2','membership_applications'],['D3','members'],['D4','attendance'],['D5','products'],['D6','sales'],['D7','sale_items'],['D8','membership_history'],['D9','activity_logs'],['D10','mobile_attendance_pairing_policy'],['D11','mobile_attendance_scan_sessions'],['D13','private.attendance_scan_requests'],['D14','private.account_sessions']];
const groups=definitions.map(([id,name],i)=>({ids:[id],name,y:50+i*220}));
for(const g of groups){
 Object.assign(g,{x:40,w:510,h:190,uses:0});g.id=vertex('','shape=partialRectangle;top=1;left=1;bottom=1;right=0;fillColor=#ffffff;strokeColor=#000000;strokeWidth=2;',g.x,g.y,g.w,g.h);
 svg.push(`<path d="M 550 ${g.y} H 40 V ${g.y+190} H 550 M 135 ${g.y} V ${g.y+190}" fill="white" stroke="black" stroke-width="2"/>`);
 vertex('','shape=line;direction=south;strokeColor=#000000;',135,g.y,1,190);text(g.ids[0],40,g.y+75,90,26);text(g.name,145,g.y+75,395,25);
}
const users=new Map();for(const [name,y] of [['Member / Applicant',650],['Authorized Staff',1200],['Administrator',1800]]){
 const u={x:3820,y,w:425,h:250,uses:0};u.id=box(u.x,u.y,u.w,u.h);text(name,u.x,u.y+105,u.w,29);users.set(name,u);
}
function route(from,to,points,label,lx,ly,lw,both,side){
 const r={from,to,points,label,both,side,cellIndex:cells.length};
 const first=points[0],last=points.at(-1),way=points.slice(1,-1).map(([x,y])=>`<mxPoint x="${x}" y="${y}"/>`).join('');
 cells.push(`<mxCell id="e${routes.length}" value="" style="edgeStyle=segmentEdgeStyle;jumpStyle=arc;jumpSize=6;strokeColor=#000000;strokeWidth=1.4;startArrow=${both?'block':'none'};endArrow=block;exitX=${(first[0]-from.x)/from.w};exitY=${(first[1]-from.y)/from.h};entryX=${(last[0]-to.x)/to.w};entryY=${(last[1]-to.y)/to.h};exitPerimeter=0;entryPerimeter=0;" edge="1" parent="1" source="${from.id}" target="${to.id}"><mxGeometry relative="1" as="geometry"><Array as="points">${way}</Array></mxGeometry></mxCell>`);
 routes.push(r);text(label,lx,ly,lw,24);
}
const actorLabels=[
 ['Credentials / access result','Credentials / access result','Credentials / access result'],
 ['Registration / status','Review decision / result','Review decision / result'],
 ['Profile / counter / staff actions','Counter entry / result','Own changes / details'],
 ['Renewal request / status','Review decision / result','Review decision / result'],
 ['Visit / scan / pairing data','QR scan / permitted visits','Own visit query / history'],
 ['Product / stock changes','Sales catalog query / results','Active catalog query / results'],
 ['Sale entry / transactions','Sale entry / own sales'],['Report query / output'],['Log query / filtered results']
];
let leftIndex=0,rightIndex=0;
const processPortYs=ps.flatMap((p,i)=>{
 const used=groups.filter(g=>p.Stores.some(s=>g.ids.includes(s[0])));
 return used.map((g,k)=>50+i*350+75+k*43);
});
function storePort(g){
 g.ports??=[];const ideal=g.y+15+(g.uses++)*17;
 const possible=Array.from({length:167},(_,i)=>g.y+12+i).filter(y=>processPortYs.every(v=>Math.abs(v-y)>=10)&&g.ports.every(v=>Math.abs(v-y)>=12));
 possible.sort((a,b)=>Math.abs(a-ideal)-Math.abs(b-ideal));
 if(!possible.length)throw Error('Insufficient store port spacing');
 const y=possible[0];g.ports.push(y);return y;
}
for(let i=0;i<9;i++){
 const p={x:1710,y:50+i*350,w:430,h:265};p.id=box(p.x,p.y,p.w,p.h,true);
 svg.push(`<path d="M ${p.x} ${p.y+55} H ${p.x+p.w}" stroke="black" stroke-width="2"/>`);vertex('','shape=line;strokeColor=#000000;',p.x,p.y+55,p.w,1);text(ps[i].Id,p.x,p.y+8,p.w,30);
 let line='',lines=[];for(const word of ps[i].Name.split(' ')){if((line+' '+word).trim().length>25){lines.push(line);line=word;}else line=(line+' '+word).trim();}if(line)lines.push(line);lines.forEach((v,k)=>text(v,p.x,p.y+95+k*38,p.w,28));
 const used=groups.map(g=>({g,items:ps[i].Stores.filter(s=>g.ids.includes(s[0]))})).filter(v=>v.items.length);
 used.forEach(({g,items},k)=>{
  const read=items.some(s=>s[3]),write=items.some(s=>s[2]),py=p.y+75+k*43,gy=storePort(g),lane=620+leftIndex++*12;
  const pts=[[g.x+g.w,gy],[lane,gy],[lane,py],[p.x,py]];
  const storeLabels={D0:'Account / session data',D1:'Profile / role data',D2:'Application / review data',D3:'Member / membership data',D4:'Visit / time records',D5:'Product / stock data',D6:'Transaction records',D7:'Sale-line records',D8:'Membership history',D9:write?'Operation events':'Filtered log data',D10:'Pairing policy',D11:'Pairing session data',D13:'Scan request / result',D14:'Session ownership'};
  const label=i===7?'Report source data':storeLabels[g.ids[0]];
  represented+=items.reduce((n,s)=>n+Number(!!s[2])+Number(!!s[3]),0);
  route(read?g:p,read?p:g,read?pts:pts.toReversed(),label,1180,py-39,510,read&&write,'store');
 });
 actors[i].forEach(([name],k)=>{
  const key=name==='Member'||name==='Applicant'?'Member / Applicant':name,u=users.get(key),py=p.y+100+k*65,uy=u.y+20+(u.uses++)*25,lane=2690+rightIndex++*45;
  route(p,u,[[p.x+p.w,py],[lane,py],[lane,uy],[u.x,uy]],actorLabels[i][k],2150,py-39,520,true,'actor');represented+=2;
 });
}
if(represented!==102)throw Error('A detailed flow is missing from the summaries');
function cost(){const segs=routes.flatMap((r,ri)=>r.points.slice(1).map((b,k)=>({a:r.points[k],b,ri})));let n=0;
 for(let i=0;i<segs.length;i++)for(let j=i+1;j<segs.length;j++){
  const a=segs[i],b=segs[j];if(a.ri===b.ri)continue;const ah=a.a[1]===a.b[1],bh=b.a[1]===b.b[1];if(ah===bh)continue;const h=ah?a:b,v=ah?b:a;
  if(v.a[0]>Math.min(h.a[0],h.b[0])&&v.a[0]<Math.max(h.a[0],h.b[0])&&h.a[1]>Math.min(v.a[1],v.b[1])&&h.a[1]<Math.max(v.a[1],v.b[1]))n++;
 }return n;}
const before=cost();let best=before;
for(let pass=0;pass<8;pass++){let improved=false;
 for(let a=0;a<routes.length;a++)for(let b=a+1;b<routes.length;b++){
  const p=routes[a],q=routes[b];if(p.side!==q.side)continue;const x=p.points[1][0],y=q.points[1][0];p.points[1][0]=p.points[2][0]=y;q.points[1][0]=q.points[2][0]=x;
  const c=cost();if(c<best){best=c;improved=true;}else{p.points[1][0]=p.points[2][0]=x;q.points[1][0]=q.points[2][0]=y;}
 }if(!improved)break;
}
// Jointly optimize track order and ports on shared actors and stores.
let seed=71931;
function random(){seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/4294967296;}
function terminal(r){if(r.side==='actor')return {node:r.to,index:3,adj:2};return r.from.x<100?{node:r.from,index:0,adj:1}:{node:r.to,index:3,adj:2};}
let current=cost(),bestPoints=routes.map(r=>r.points.map(p=>[...p]));
for(let iter=0;iter<10000;iter++){
 const a=Math.floor(random()*routes.length),b=Math.floor(random()*routes.length);if(a===b)continue;
 const p=routes[a],q=routes[b],portSwap=random()<.5;if(p.side!==q.side)continue;
 let undo;
 if(portSwap){
  const t=terminal(p),u=terminal(q);if(t.node!==u.node)continue;
  const y=p.points[t.index][1],z=q.points[u.index][1];
  p.points[t.index][1]=p.points[t.adj][1]=z;q.points[u.index][1]=q.points[u.adj][1]=y;
  undo=()=>{p.points[t.index][1]=p.points[t.adj][1]=y;q.points[u.index][1]=q.points[u.adj][1]=z;};
 }else{
  const x=p.points[1][0],y=q.points[1][0];p.points[1][0]=p.points[2][0]=y;q.points[1][0]=q.points[2][0]=x;
  undo=()=>{p.points[1][0]=p.points[2][0]=x;q.points[1][0]=q.points[2][0]=y;};
 }
 const next=cost(),temp=1.8*(1-iter/10000)+.04;
 if(next<=current||random()<Math.exp((current-next)/temp)){
  current=next;if(next<best){best=next;bestPoints=routes.map(r=>r.points.map(p=>[...p]));}
 }else undo();
}
for(let i=0;i<routes.length;i++)routes[i].points=bestPoints[i];
const segs=routes.flatMap((r,ri)=>r.points.slice(1).map((b,k)=>({a:r.points[k],b,ri})));
for(const [ri,r] of routes.entries()){
 const pts=r.points,way=pts.slice(1,-1).map(([x,y])=>`<mxPoint x="${x}" y="${y}"/>`).join('');
 cells[r.cellIndex]=cells[r.cellIndex].replace(/<Array as="points">.*?<\/Array>/,`<Array as="points">${way}</Array>`).replace(/exitY=[^;]+;/,`exitY=${(pts[0][1]-r.from.y)/r.from.h};`).replace(/entryY=[^;]+;/,`entryY=${(pts.at(-1)[1]-r.to.y)/r.to.h};`);
 let d='M '+pts[0].join(' ');
 for(let k=1;k<pts.length;k++){
  const a=pts[k-1],b=pts[k];if(a[0]!==b[0]){d+=' L '+b.join(' ');continue;}
  const x=a[0],lo=Math.min(a[1],b[1]),hi=Math.max(a[1],b[1]),sign=Math.sign(b[1]-a[1]);
  const cuts=[...new Set(segs.filter(h=>h.ri!==ri&&h.a[1]===h.b[1]&&x>Math.min(h.a[0],h.b[0])&&x<Math.max(h.a[0],h.b[0])&&h.a[1]>lo+9&&h.a[1]<hi-9).map(h=>h.a[1]))].sort((u,v)=>sign*(u-v));
  for(const y of cuts)d+=` L ${x} ${y-sign*6} C ${x+8} ${y-sign*6} ${x+8} ${y+sign*6} ${x} ${y+sign*6}`;
  d+=' L '+b.join(' ');
 }
 svg.push(`<path d="${d}" fill="none" stroke="white" stroke-width="5"/><path d="${d}" fill="none" stroke="black" stroke-width="1.4" ${r.both?'marker-start="url(#arrow)"':''} marker-end="url(#arrow)"/>`);
}


writeFileSync(join(dir,'03-dfd-simple.svg'),`<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}"><defs><marker id="arrow" markerWidth="8" markerHeight="6" refX="8" refY="3" orient="auto-start-reverse"><path d="M0 0 L8 3 L0 6 Z"/></marker></defs><rect width="${W}" height="${H}" fill="white"/>${svg.join('')}</svg>`);
writeFileSync(join(dir,'03-dfd-simple.drawio'),`<mxfile host="app.diagrams.net"><diagram id="dfd" name="Nine-function DFD"><mxGraphModel page="1" pageWidth="${W}" pageHeight="${H}"><root><mxCell id="0"/><mxCell id="1" parent="0"/>${cells.join('')}</root></mxGraphModel></diagram></mxfile>`);
writeFileSync(join(dir,'_Sources/dfd-summary-validation.json'),JSON.stringify({processes:9,actors:3,individualStores:groups.map(g=>({id:g.ids[0],name:g.name})),connectors:routes.length,representedDirectionalFlows:represented,crossingsBefore:before,crossingsAfter:best},null,2));
console.log(`Verified 9 functions, 3 shared actors, 14 individual stores, ${routes.length} summary connectors representing 102 directed flows. Reduced crossings ${before} -> ${best}.`);
