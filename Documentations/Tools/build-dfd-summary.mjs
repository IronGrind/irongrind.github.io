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
const W=2400,H=3300,cells=[],svg=[];let serial=0;const segments=[];
const esc=s=>String(s).replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;').replaceAll('"','&quot;');
function v(t,style,x,y,w,h){const id='c'+(++serial);cells.push(`<mxCell id="${id}" value="${esc(t)}" style="${style}" vertex="1" parent="1"><mxGeometry x="${x}" y="${y}" width="${w}" height="${h}" as="geometry"/></mxCell>`);return id;}
function text(t,x,y,w,size=27){size=Math.min(size,w/(Math.max(1,t.length)*.55));v(t,`text;html=0;whiteSpace=wrap;align=center;verticalAlign=middle;fontFamily=Arial;fontSize=${size};`,x,y,w,42);svg.push(`<text x="${x+w/2}" y="${y+30}" text-anchor="middle" font-family="Arial" font-size="${size}">${esc(t)}</text>`);}
function box(x,y,w,h,round=false){svg.push(`<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="${round?12:0}" fill="white" stroke="black" stroke-width="2"/>`);return v('',`rounded=${round?1:0};fillColor=#ffffff;strokeColor=#000000;strokeWidth=2;`,x,y,w,h);}
function arrow(from,to,y,label,x1,x2,both){
 const id='e'+(++serial);cells.push(`<mxCell id="${id}" style="edgeStyle=none;strokeColor=#000000;strokeWidth=2;startArrow=${both?'block':'none'};endArrow=block;exitX=${(x1-from.x)/from.w};exitY=${(y-from.y)/from.h};entryX=${(x2-to.x)/to.w};entryY=${(y-to.y)/to.h};exitPerimeter=0;entryPerimeter=0;" edge="1" parent="1" source="${from.id}" target="${to.id}"><mxGeometry relative="1" as="geometry"/></mxCell>`);
 svg.push(`<path d="M ${x1} ${y} H ${x2}" fill="none" stroke="black" stroke-width="2" marker-end="url(#arrow)" ${both?'marker-start="url(#arrow)"':''}/>`);text(label,Math.min(x1,x2)+10,y-52,Math.abs(x2-x1)-20,25);segments.push({a:Math.min(x1,x2),b:Math.max(x1,x2),y});
}
for(let i=0;i<9;i++){
 const [storeName,ids,data,role,userData]=specs[i],top=50+i*350;
 const p={x:1030,y:top,w:400,h:265};p.id=box(p.x,p.y,p.w,p.h,true);
 svg.push(`<path d="M ${p.x} ${top+55} H ${p.x+p.w}" stroke="black" stroke-width="2"/>`);v('','shape=line;strokeColor=#000000;',p.x,top+55,p.w,1);text(ps[i].Id,p.x,top+8,p.w,30);
 let lines=[],line='';for(const word of ps[i].Name.split(' ')){if((line+' '+word).trim().length>24){lines.push(line);line=word}else line=(line+' '+word).trim();}if(line)lines.push(line);lines.forEach((s,k)=>text(s,p.x,top+95+k*38,p.w,28));
 const s={x:35,y:top+85,w:455,h:150};s.id=v('','shape=partialRectangle;top=1;left=1;bottom=1;right=0;fillColor=#ffffff;strokeColor=#000000;strokeWidth=2;',s.x,s.y,s.w,s.h);
 svg.push(`<path d="M 490 ${s.y} H 35 V ${s.y+150} H 490 M 35 ${s.y+55} H 490" fill="white" stroke="black" stroke-width="2"/>`);v('','shape=line;strokeColor=#000000;',s.x,s.y+55,s.w,1);text(ids,s.x,s.y+10,s.w,25);text(storeName,s.x+10,s.y+80,s.w-20,25);
 const u={x:1970,y:top+85,w:395,h:150};u.id=box(u.x,u.y,u.w,u.h);role.split('; ').forEach((r,k)=>text(r,u.x,u.y+12+k*39,u.w,26));
 const cy=top+175;
 arrow(s,p,cy,data,490,p.x,i<7);
 arrow(p,u,cy,userData,p.x+p.w,u.x,true);
}
for(let i=0;i<segments.length;i++)for(let j=i+1;j<segments.length;j++){const a=segments[i],b=segments[j];if(a.y===b.y&&Math.min(a.b,b.b)>Math.max(a.a,b.a))throw Error('Overlap');}
text('Summary view: grouped labels reference existing actors and stores; they do not create new tables or grant shared permissions.',35,3215,2330,25);
text('Two arrowheads summarize related input/output flows. Detailed operations and role restrictions are explained in Chapter 3.',35,3260,2330,25);
writeFileSync(join(dir,'03-dfd-simple.svg'),`<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}"><defs><marker id="arrow" markerWidth="8" markerHeight="6" refX="8" refY="3" orient="auto-start-reverse"><path d="M0 0 L8 3 L0 6 Z"/></marker></defs><rect width="${W}" height="${H}" fill="white"/>${svg.join('')}</svg>`);
writeFileSync(join(dir,'03-dfd-simple.drawio'),`<mxfile host="app.diagrams.net"><diagram id="summary" name="Level 1 summary"><mxGraphModel page="1" pageWidth="${W}" pageHeight="${H}"><root><mxCell id="0"/><mxCell id="1" parent="0"/>${cells.join('')}</root></mxGraphModel></diagram></mxfile>`);
console.log('Verified one-page summary with nine processes and 18 connectors: no crossings or shared segments.');
