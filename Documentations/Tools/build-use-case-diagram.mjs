import {writeFileSync} from 'node:fs';
import {dirname,join} from 'node:path';
import {fileURLToPath} from 'node:url';
const dir=join(dirname(fileURLToPath(import.meta.url)),'..','Chapter 3 Diagrams');
const W=2200,H=2400,cells=[],shapes=[],edges=[];let serial=0;
const esc=s=>String(s).replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;').replaceAll('"','&quot;');
function vertex(value,style,x,y,w,h,parent='1'){const id='v'+(++serial);cells.push(`<mxCell id="${id}" value="${esc(value)}" style="${style}" vertex="1" parent="${parent}"><mxGeometry x="${x}" y="${y}" width="${w}" height="${h}" as="geometry"/></mxCell>`);return id;}
function text(value,x,y,w,size=30){vertex(value,`text;html=0;whiteSpace=wrap;align=center;fontFamily=Arial;fontSize=${size};`,x,y,w,50);shapes.push(`<text x="${x+w/2}" y="${y+35}" text-anchor="middle" font-family="Arial" font-size="${size}">${esc(value)}</text>`);}
const labels=['User Login','Membership Application','User Management','Renewals','QR Attendance','Product & Inventory','Sales','Generate Reports','Activity Logs'];
const boundary=vertex('','rounded=0;fillColor=#d5e2f5;strokeColor=#000000;strokeWidth=2;',700,70,800,2200);
const background=`<rect x="700" y="70" width="800" height="2200" fill="#d5e2f5" stroke="black" stroke-width="2"/>`;
text('IronGrind',700,82,800,32);
const uses=labels.map((label,i)=>{
 const c={x:850,y:150+i*240,w:500,h:140,label};
 c.id=vertex(label,'ellipse;whiteSpace=wrap;html=0;fillColor=#ffffff;strokeColor=#000000;strokeWidth=2;fontFamily=Arial;fontSize=30;',c.x,c.y,c.w,c.h);
 shapes.push(`<ellipse cx="${c.x+250}" cy="${c.y+70}" rx="250" ry="70" fill="white" stroke="black" stroke-width="2"/><text x="${c.x+250}" y="${c.y+80}" text-anchor="middle" font-family="Arial" font-size="30">${esc(label)}</text>`);
 return c;
});
const actors=[
 {name:'Member / Applicant',x:125,y:500,side:'left',useCases:[0,1,2,3,4,5]},
 {name:'Authorized Staff',x:125,y:1500,side:'left',useCases:[0,1,2,3,4,5,6]},
 {name:'Administrator',x:1950,y:1100,side:'right',useCases:[0,1,2,3,4,5,6,7,8]}
];
let leftLane=0,rightLane=0;
for(const actor of actors){
 actor.id=vertex('', 'group;',actor.x,actor.y,90,160);
 vertex('','ellipse;fillColor=#e5e7eb;strokeColor=#9ca3af;strokeWidth=1;',0,25,90,90,actor.id);
 vertex('','ellipse;fillColor=#64748b;strokeColor=none;',31,40,28,28,actor.id);
 vertex('','rounded=1;arcSize=80;fillColor=#64748b;strokeColor=none;',17,80,56,27,actor.id);
 const cx=actor.x+45;
 shapes.push(`<circle cx="${cx}" cy="${actor.y+70}" r="45" fill="#e5e7eb" stroke="#9ca3af"/><circle cx="${cx}" cy="${actor.y+54}" r="14" fill="#64748b"/><rect x="${actor.x+17}" y="${actor.y+80}" width="56" height="27" rx="13" fill="#64748b"/>`);
 text(actor.name,actor.x-95,actor.y+180,280,28);
 actor.useCases.forEach((ui,k)=>{
  const u=uses[ui],left=actor.side==='left';
  const sx=actor.x+(left?90:0),sy=actor.y+70;
  const offset=left?(actor.name==='Member / Applicant'?-17:17):0;
  const ey=u.y+70+offset;
  const ex=left?u.x+250-250*Math.sqrt(1-(offset/70)**2):u.x+500;
  // Keep the fan outside the ovals, then enter the target horizontally.
  const points=[[sx,sy],[left?780:1420,ey],[ex,ey]];
  const id='e'+edges.length;
  const way=points.slice(1,-1).map(([x,y])=>`<mxPoint x="${x}" y="${y}"/>`).join('');
  cells.push(`<mxCell id="${id}" style="edgeStyle=none;startArrow=none;endArrow=none;strokeColor=#000000;strokeWidth=1.6;exitX=${left?1:0};exitY=${70/160};entryX=${(ex-u.x)/u.w};entryY=${(ey-u.y)/u.h};exitPerimeter=0;entryPerimeter=0;" edge="1" parent="1" source="${actor.id}" target="${u.id}"><mxGeometry relative="1" as="geometry"><Array as="points">${way}</Array></mxGeometry></mxCell>`);
  edges.push({actor:actor.name,useCase:u.label,points});
 });
}
const segments=edges.flatMap((e,ri)=>e.points.slice(1).map((b,k)=>({a:e.points[k],b,ri})));
const lines=[];
for(const [ri,e] of edges.entries()){
 let d='M '+e.points[0].join(' ');
 for(let k=1;k<e.points.length;k++){
  const a=e.points[k-1],b=e.points[k];if(a[0]!==b[0]){d+=' L '+b.join(' ');continue;}
  const x=a[0],lo=Math.min(a[1],b[1]),hi=Math.max(a[1],b[1]),sign=Math.sign(b[1]-a[1]);
  const cuts=[...new Set(segments.filter(s=>s.ri!==ri&&s.a[1]===s.b[1]&&x>Math.min(s.a[0],s.b[0])&&x<Math.max(s.a[0],s.b[0])&&s.a[1]>lo+9&&s.a[1]<hi-9).map(s=>s.a[1]))].sort((a,b)=>sign*(a-b));
  for(const y of cuts)d+=` L ${x} ${y-sign*6} C ${x+8} ${y-sign*6} ${x+8} ${y+sign*6} ${x} ${y+sign*6}`;
  d+=' L '+b.join(' ');
 }
 lines.push(`<path d="${d}" fill="none" stroke="black" stroke-width="1.6"/>`);
}
if(edges.length!==22||uses.length!==9)throw Error('Use-case coverage mismatch');
const required=[['Member / Applicant','User Management'],['Member / Applicant','Product & Inventory'],['Authorized Staff','Product & Inventory']];
for(const [actor,useCase] of required)if(!edges.some(e=>e.actor===actor&&e.useCase===useCase))throw Error('Missing required association');
writeFileSync(join(dir,'04-use-cases.svg'),`<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}"><rect width="${W}" height="${H}" fill="white"/>${background}${lines.join('')}${shapes.join('')}</svg>`);
writeFileSync(join(dir,'04-use-cases.drawio'),`<mxfile host="app.diagrams.net"><diagram id="use-cases" name="Nine-function use cases"><mxGraphModel page="1" pageWidth="${W}" pageHeight="${H}"><root><mxCell id="0"/><mxCell id="1" parent="0"/>${cells.join('')}</root></mxGraphModel></diagram></mxfile>`);
writeFileSync(join(dir,'_Sources/use-case-associations.json'),JSON.stringify({functions:labels,actors:actors.map(a=>({name:a.name,functions:a.useCases.map(i=>labels[i])})),associationCount:edges.length},null,2));
console.log('Verified nine function ovals, three actors, and 22 undirected associations, including all three requested additions.');
