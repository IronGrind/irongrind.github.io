import {readFileSync,writeFileSync} from 'node:fs';
import {dirname,join} from 'node:path';
import {fileURLToPath} from 'node:url';
const dir=join(dirname(fileURLToPath(import.meta.url)),'..','Chapter 3 Diagrams');
const ps=JSON.parse(readFileSync(join(dir,'03-gane-sarson-flows.json'),'utf8').replace(/^\uFEFF/,''));
const specs=[
 ['Accounts, profiles, sessions and logs','D0, D1, D14, D9','Account / session records','Member / Applicant; Administrator; Authorized Staff','Credentials / access result'],
 ['Application and membership stores','D1, D2, D3, D6, D7, D9','Application / approval records','Applicant; Administrator; Authorized Staff','Application / review information'],
 ['Account and membership stores','D0, D1, D3, D6, D7, D8, D9','Profile / membership records','Member; Administrator; Authorized Staff','Own details / permitted counter actions'],
 ['Application and membership stores','D2, D3, D6, D7, D8, D9','Renewal / membership records','Member; Administrator; Authorized Staff','Renewal request / review information'],
 ['Member, attendance and scanner stores','D3, D4, D9, D10, D11, D13','Visit / scanner records','Member; Administrator; Authorized Staff','Own visits / authorized scan operations'],
 ['Product and activity-log stores','D5, D9','Catalog / inventory records','Member; Administrator; Authorized Staff','Catalog query / admin stock changes'],
 ['Product, sale, item and log stores','D5, D6, D7, D9','Product / transaction records','Administrator; Authorized Staff','Sale entry / permitted sale records'],
 ['Operational report sources','D2-D8','Report source records','Administrator','Report query / report output'],
 ['Activity-log store','D9','Recorded activity data','Administrator','Log query / filtered results']
];
const W=3600,H=3300,cells=[],svg=[];let serial=0;const segments=[];
const esc=s=>String(s).replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;').replaceAll('"','&quot;');
function v(t,style,x,y,w,h){const id='c'+(++serial);cells.push(`<mxCell id="${id}" value="${esc(t)}" style="${style}" vertex="1" parent="1"><mxGeometry x="${x}" y="${y}" width="${w}" height="${h}" as="geometry"/></mxCell>`);return id;}
function text(t,x,y,w,size=27){size=Math.min(size,w/(Math.max(1,t.length)*.55));v(t,`text;html=0;whiteSpace=wrap;align=center;verticalAlign=middle;fontFamily=Arial;fontSize=${size};`,x,y,w,42);svg.push(`<text x="${x+w/2}" y="${y+30}" text-anchor="middle" font-family="Arial" font-size="${size}">${esc(t)}</text>`);}
function box(x,y,w,h,round=false){svg.push(`<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="${round?12:0}" fill="white" stroke="black" stroke-width="2"/>`);return v('',`rounded=${round?1:0};fillColor=#ffffff;strokeColor=#000000;strokeWidth=2;`,x,y,w,h);}
function arrow(from,to,y,label,x1,x2,both){
 const id='e'+(++serial);cells.push(`<mxCell id="${id}" style="edgeStyle=none;strokeColor=#000000;strokeWidth=2;startArrow=${both?'block':'none'};endArrow=block;exitX=${(x1-from.x)/from.w};exitY=${(y-from.y)/from.h};entryX=${(x2-to.x)/to.w};entryY=${(y-to.y)/to.h};exitPerimeter=0;entryPerimeter=0;" edge="1" parent="1" source="${from.id}" target="${to.id}"><mxGeometry relative="1" as="geometry"/></mxCell>`);
 svg.push(`<path d="M ${x1} ${y} H ${x2}" fill="none" stroke="black" stroke-width="2" marker-end="url(#arrow)" ${both?'marker-start="url(#arrow)"':''}/>`);text(label,Math.min(x1,x2)+10,y-52,Math.abs(x2-x1)-20,25);segments.push({a:Math.min(x1,x2),b:Math.max(x1,x2),y});
}
const actorFlows=JSON.parse(readFileSync(join(dir,'_Sources/dfd-actor-flows.json'),'utf8').replace(/^\uFEFF/,''));
const users=new Map();
for(const [name,y] of [['Administrator',2150],['Authorized Staff',1400],['Member / Applicant',650]]){
 const u={x:3120,y,w:425,h:250,uses:0};u.id=box(u.x,u.y,u.w,u.h);text(name,u.x,u.y+105,u.w,28);users.set(name,u);
}
const routed=[];
function userRoute(p,u,cy,label){
  const index=u.uses++,uy=u.y+20+index*25;
 const role=u===users.get('Administrator')?'A':u===users.get('Authorized Staff')?'S':'M';
 const lane=(role==='A'?2670:role==='S'?2310:1990)+index*42;
 const tag=role+(index+1);
 const points=[[p.x+p.w,cy],[lane,cy],[lane,uy],[u.x,uy]];
 const id='e'+(++serial);
 cells.push(`<mxCell id="${id}" style="edgeStyle=segmentEdgeStyle;jumpStyle=arc;jumpSize=8;strokeColor=#000000;strokeWidth=1.4;startArrow=block;endArrow=block;exitX=1;exitY=${(cy-p.y)/p.h};entryX=0;entryY=${(uy-u.y)/u.h};exitPerimeter=0;entryPerimeter=0;" edge="1" parent="1" source="${p.id}" target="${u.id}"><mxGeometry relative="1" as="geometry"><Array as="points">${points.slice(1,-1).map(([x,y])=>`<mxPoint x="${x}" y="${y}"/>`).join('')}</Array></mxGeometry></mxCell>`);
 points.role=role;points.cellIndex=cells.length-1;routed.push(points);text(label,1445,cy-40,515,24);
}
for(let i=0;i<9;i++){
 const [storeName,ids,data,role,userData]=specs[i],top=50+i*350;
 const p={x:1030,y:top,w:400,h:265};p.id=box(p.x,p.y,p.w,p.h,true);
 svg.push(`<path d="M ${p.x} ${top+55} H ${p.x+p.w}" stroke="black" stroke-width="2"/>`);v('','shape=line;strokeColor=#000000;',p.x,top+55,p.w,1);text(ps[i].Id,p.x,top+8,p.w,30);
 let lines=[],line='';for(const word of ps[i].Name.split(' ')){if((line+' '+word).trim().length>24){lines.push(line);line=word}else line=(line+' '+word).trim();}if(line)lines.push(line);lines.forEach((s,k)=>text(s,p.x,top+95+k*38,p.w,28));
 const s={x:35,y:top+85,w:455,h:150};s.id=v('','shape=partialRectangle;top=1;left=1;bottom=1;right=0;fillColor=#ffffff;strokeColor=#000000;strokeWidth=2;',s.x,s.y,s.w,s.h);
 svg.push(`<path d="M 490 ${s.y} H 35 V ${s.y+150} H 490 M 35 ${s.y+55} H 490" fill="white" stroke="black" stroke-width="2"/>`);v('','shape=line;strokeColor=#000000;',s.x,s.y+55,s.w,1);text(ids,s.x,s.y+10,s.w,25);text(storeName,s.x+10,s.y+80,s.w-20,25);

 const cy=top+175;
 arrow(s,p,cy,data,490,p.x,i<7);
 actorFlows[i].forEach(([name,input,output],k)=>{
 const roleName=name==='Applicant'||name==='Member'?'Member / Applicant':name;
  const labels=[
 ['Credentials / access result','Credentials / access result','Credentials / access result'],
 ['Registration / status','Review decision / result','Review decision / result'],
 ['Profile / counter / staff actions','Counter entry / result','Own changes / details'],
 ['Renewal request / status','Review decision / result','Review decision / result'],
 ['Visit / scan / pairing data','QR scan / permitted visits','Own visit query / history'],
 ['Product / stock changes','Sales catalog query / results','Active catalog query / results'],
 ['Sale entry / transactions','Sale entry / own sales'],
 ['Report query / output'],['Log query / filtered results']
 ];
 userRoute(p,users.get(roleName),top+100+k*65,labels[i][k]);
 });
}
for(let i=0;i<segments.length;i++)for(let j=i+1;j<segments.length;j++){const a=segments[i],b=segments[j];if(a.y===b.y&&Math.min(a.b,b.b)>Math.max(a.a,b.a))throw Error('Overlap');}
// Reorder tracks within each role's corridor to reduce crossings.
function crossingCost(){
 const ss=routed.flatMap((p,ri)=>p.slice(1).map((b,k)=>({a:p[k],b,ri})));
 let cost=0;for(let i=0;i<ss.length;i++)for(let j=i+1;j<ss.length;j++){
 const a=ss[i],b=ss[j];if(a.ri===b.ri)continue;
 const ah=a.a[1]===a.b[1],bh=b.a[1]===b.b[1];if(ah===bh)continue;
 const h=ah?a:b,v=ah?b:a;
 if(v.a[0]>Math.min(h.a[0],h.b[0])&&v.a[0]<Math.max(h.a[0],h.b[0])&&h.a[1]>Math.min(v.a[1],v.b[1])&&h.a[1]<Math.max(v.a[1],v.b[1]))cost++;
 }return cost;
}
const initialCrossings=crossingCost();let best=initialCrossings;
for(let pass=0;pass<8;pass++){
 let improved=false;
 for(let a=0;a<routed.length;a++)for(let b=a+1;b<routed.length;b++){
 
 const x=routed[a][1][0],y=routed[b][1][0];
 routed[a][1][0]=routed[a][2][0]=y;routed[b][1][0]=routed[b][2][0]=x;
 const score=crossingCost();if(score<best){best=score;improved=true;}
 else{routed[a][1][0]=routed[a][2][0]=x;routed[b][1][0]=routed[b][2][0]=y;}
 }if(!improved)break;
}
for(const p of routed){
 const way=p.slice(1,-1).map(([x,y])=>`<mxPoint x="${x}" y="${y}"/>`).join('');
 cells[p.cellIndex]=cells[p.cellIndex].replace(/<Array as="points">.*?<\/Array>/,`<Array as="points">${way}</Array>`);
}
console.log(`Reduced crossings from ${initialCrossings} to ${best}; every connector keeps its own track.`);
// Use continuous bridge arcs at crossings instead of visually broken tracks.
const parts=routed.flatMap((points,ri)=>points.slice(1).map((b,j)=>({a:points[j],b,ri})));
let bridgeCount=0;
for(let ri=0;ri<routed.length;ri++){
 const points=routed[ri];let d='M '+points[0].join(' ');
 for(let k=1;k<points.length;k++){
  const a=points[k-1],b=points[k];
  if(a[0]!==b[0]){d+=' L '+b.join(' ');continue;}
  const x=a[0],lo=Math.min(a[1],b[1]),hi=Math.max(a[1],b[1]),sign=Math.sign(b[1]-a[1]);
  const cuts=[...new Set(parts.filter(h=>h.ri!==ri&&h.a[1]===h.b[1]&&x>Math.min(h.a[0],h.b[0])&&x<Math.max(h.a[0],h.b[0])&&h.a[1]>lo+9&&h.a[1]<hi-9).map(h=>h.a[1]))].sort((u,v)=>sign*(u-v));
  for(const y of cuts){d+=` L ${x} ${y-sign*7} C ${x+10} ${y-sign*7} ${x+10} ${y+sign*7} ${x} ${y+sign*7}`;bridgeCount++;}
  d+=' L '+b.join(' ');
 }
 svg.push(`<path d="${d}" fill="none" stroke="white" stroke-width="5.5"/><path d="${d}" fill="none" stroke="black" stroke-width="1.4" marker-start="url(#arrow)" marker-end="url(#arrow)"/>`);
}
text('Summary view: grouped labels reference existing actors and stores; they do not create new tables or grant shared permissions.',35,3215,3530,25);
text('Two arrowheads summarize related input/output flows. Detailed operations and role restrictions are explained in Chapter 3.',35,3260,3530,25);
writeFileSync(join(dir,'03-dfd-simple.svg'),`<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}"><defs><marker id="arrow" markerWidth="8" markerHeight="6" refX="8" refY="3" orient="auto-start-reverse"><path d="M0 0 L8 3 L0 6 Z"/></marker></defs><rect width="${W}" height="${H}" fill="white"/>${svg.join('')}</svg>`);
writeFileSync(join(dir,'03-dfd-simple.drawio'),`<mxfile host="app.diagrams.net"><diagram id="summary" name="Level 1 summary"><mxGraphModel page="1" pageWidth="${W}" pageHeight="${H}"><root><mxCell id="0"/><mxCell id="1" parent="0"/>${cells.join('')}</root></mxGraphModel></diagram></mxfile>`);
console.log('Created one diagram with nine processes, three shared actors, nine grouped store connections and '+routed.length+' role-specific summary connections. Tracks are spaced 42 units apart; crossings use continuous bridge arcs.');
