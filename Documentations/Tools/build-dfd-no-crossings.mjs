import {readFileSync,writeFileSync} from 'node:fs';
import {dirname,join} from 'node:path';
import {fileURLToPath} from 'node:url';
const dir=join(dirname(fileURLToPath(import.meta.url)),'..','Chapter 3 Diagrams');
const read=n=>JSON.parse(readFileSync(join(dir,n),'utf8').replace(/^\uFEFF/,''));
const ps=read('03-gane-sarson-flows.json'),actors=read('_Sources/dfd-actor-flows.json');
const esc=s=>String(s).replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;').replaceAll('"','&quot;');
const W=2400,H=1200;let total=0;const panels=[],pages=[];
for(let i=0;i<9;i++){
 let serial=0;const cells=[],svg=[],segments=[];
 const cell=(v,style,x,y,w,h)=>{const id='v'+(++serial);cells.push(`<mxCell id="${id}" value="${esc(v)}" style="${style}" vertex="1" parent="1"><mxGeometry x="${x}" y="${y}" width="${w}" height="${h}" as="geometry"/></mxCell>`);return id;};
 function txt(s,x,y,w,size=26){size=Math.min(size,w/(Math.max(1,s.length)*.55));cell(s,`text;html=0;whiteSpace=wrap;align=center;verticalAlign=middle;fontFamily=Arial;fontSize=${size};`,x,y,w,40);svg.push(`<text x="${x+w/2}" y="${y+29}" text-anchor="middle" font-family="Arial" font-size="${size}">${esc(s)}</text>`);}
 function rect(x,y,w,h,fill='white',round=false){svg.push(`<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="${round?14:0}" fill="${fill}" stroke="black" stroke-width="2"/>`);return cell('',`rounded=${round?1:0};fillColor=${fill};strokeColor=#000000;strokeWidth=2;`,x,y,w,h);}
 const proc={x:1020,y:100,w:410,h:1010};proc.id=rect(proc.x,proc.y,proc.w,proc.h,'white',true);rect(proc.x,proc.y,proc.w,65,'#d5e2f5');txt(ps[i].Id,proc.x,proc.y+12,proc.w,30);
 const words=ps[i].Name.split(' ');let line='',names=[];for(const word of words){if((line+' '+word).trim().length>23){names.push(line);line=word;}else line=(line+' '+word).trim();}if(line)names.push(line);names.forEach((s,k)=>txt(s,proc.x,460+k*42,proc.w,29));
 function flow(s,t,sy,ty,label,lx,lw){
  if(sy!==ty)throw Error('A connector is not horizontal');
  const sx=s===proc?s.x+s.w:s.x+s.w,tx=t===proc?t.x:t.x;
  // Left-side writes travel from the process's left edge to the store's right edge.
  let x1=sx,x2=tx;
  if(s===proc&&t.x<proc.x){x1=proc.x;x2=t.x+t.w;}
  const id='e'+(++serial);cells.push(`<mxCell id="${id}" style="edgeStyle=none;endArrow=block;strokeColor=#000000;strokeWidth=1.7;exitX=${(x1-s.x)/s.w};exitY=${(sy-s.y)/s.h};entryX=${(x2-t.x)/t.w};entryY=${(ty-t.y)/t.h};exitPerimeter=0;entryPerimeter=0;" edge="1" parent="1" source="${s.id}" target="${t.id}"><mxGeometry relative="1" as="geometry"/></mxCell>`);
  svg.push(`<path d="M ${x1} ${sy} H ${x2}" fill="none" stroke="black" stroke-width="1.7" marker-end="url(#arrow)"/>`);txt(label,lx,sy-38,lw,24);segments.push({lo:Math.min(x1,x2),hi:Math.max(x1,x2),y:sy});total++;
 }
 ps[i].Stores.forEach((s,k)=>{
  const store={x:45,y:200+k*125,w:440,h:95};store.id=cell('','shape=partialRectangle;top=1;left=1;bottom=1;right=0;fillColor=#ffffff;strokeColor=#000000;',store.x,store.y,store.w,store.h);
  svg.push(`<path d="M 485 ${store.y} H 45 V ${store.y+95} H 485 M 125 ${store.y} V ${store.y+95}" fill="white" stroke="black" stroke-width="2"/>`);cell('','shape=line;direction=south;strokeColor=#000000;',125,store.y,1,95);txt(s[0],45,store.y+28,80,25);txt(s[1],130,store.y+28,350,24);
  if(s[3])flow(store,proc,store.y+25,store.y+25,s[3],500,505);
  if(s[2])flow(proc,store,store.y+77,store.y+77,s[2],500,505);
 });
 actors[i].forEach((a,k)=>{
  const user={x:1950,y:240+k*280,w:390,h:130};user.id=rect(user.x,user.y,user.w,user.h,'#d5e2f5');txt(a[0],user.x,user.y+43,user.w,28);
  flow(user,proc,user.y+30,user.y+30,a[1],1445,490);
  flow(proc,user,user.y+100,user.y+100,a[2],1445,490);
 });
 for(let a=0;a<segments.length;a++)for(let b=a+1;b<segments.length;b++)if(segments[a].y===segments[b].y&&Math.min(segments[a].hi,segments[b].hi)>Math.max(segments[a].lo,segments[b].lo))throw Error('Overlapping lines');
 txt('Process '+ps[i].Id+' — repeated actor and store names identify the same entities across panels.',40,1140,2320,24);
 panels.push(`<g transform="translate(0 ${i*H})">${svg.join('')}</g>`);
 pages.push(`<diagram id="p${i+1}" name="${esc(ps[i].Id+' '+ps[i].Name)}"><mxGraphModel page="1" pageWidth="${W}" pageHeight="${H}"><root><mxCell id="0"/><mxCell id="1" parent="0"/>${cells.join('')}</root></mxGraphModel></diagram>`);
}
if(total!==96)throw Error('Flow coverage mismatch');
writeFileSync(join(dir,'03-dfd-simple.svg'),`<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H*9}" viewBox="0 0 ${W} ${H*9}"><defs><marker id="arrow" markerWidth="8" markerHeight="6" refX="8" refY="3" orient="auto"><path d="M0 0 L8 3 L0 6 Z"/></marker></defs><rect width="${W}" height="${H*9}" fill="white"/>${panels.join('')}</svg>`);
writeFileSync(join(dir,'03-dfd-simple.drawio'),`<mxfile host="app.diagrams.net">${pages.join('')}</mxfile>`);
console.log('Verified 96 separate directional flows across nine panels: all connectors horizontal; no shared segments or crossings.');
