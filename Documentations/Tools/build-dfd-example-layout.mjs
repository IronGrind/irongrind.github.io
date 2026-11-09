import {readFileSync,writeFileSync} from 'node:fs';
import {dirname,join} from 'node:path';
import {fileURLToPath} from 'node:url';
const dir=join(dirname(fileURLToPath(import.meta.url)),'..','Chapter 3 Diagrams');
const read=name=>JSON.parse(readFileSync(join(dir,name),'utf8').replace(/^\uFEFF/,''));
const ps=read('03-gane-sarson-flows.json'), actors=read('_Sources/dfd-actor-flows.json');
const W=2400,H=4200,svg=[],cells=[];let serial=0,edges=0;
const esc=t=>String(t).replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;').replaceAll('"','&quot;');
function vertex(value,style,x,y,w,h){const id='v'+(++serial);cells.push(`<mxCell id="${id}" value="${esc(value)}" style="${style}" vertex="1" parent="1"><mxGeometry x="${x}" y="${y}" width="${w}" height="${h}" as="geometry"/></mxCell>`);return id;}
function text(t,x,y,w,size=24){size=Math.min(size,w/(Math.max(1,t.length)*0.55));vertex(t,`text;html=0;whiteSpace=wrap;align=center;fontFamily=Arial;fontSize=${size};fontColor=#000000;`,x,y,w,38);svg.push(`<text x="${x+w/2}" y="${y+28}" text-anchor="middle" font-family="Arial" font-size="${size}">${esc(t)}</text>`);}
function rect(x,y,w,h,round=false,fill='white'){svg.push(`<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="${round?12:0}" fill="${fill}" stroke="black" stroke-width="2"/>`);return vertex('',`rounded=${round?1:0};arcSize=8;fillColor=${fill};strokeColor=#000000;strokeWidth=2;`,x,y,w,h);}
const stores=new Map();for(const p of ps)for(const s of p.Stores)if(!stores.has(s[0]))stores.set(s[0],{name:s[1]});
const storeOrder=['D0','D1','D14','D2','D3','D8','D4','D10','D11','D13','D5','D6','D7','D2-D8','D9'];
for(let i=0;i<storeOrder.length;i++){
 const key=storeOrder[i],s=stores.get(key);if(!s)throw Error('Missing store '+key);
 Object.assign(s,{x:65,y:100+i*270,w:500,h:60});
 s.id=vertex('',`shape=partialRectangle;top=1;left=1;bottom=1;right=0;fillColor=#ffffff;strokeColor=#000000;`,s.x,s.y,s.w,s.h);
 svg.push(`<path d="M ${s.x+s.w} ${s.y} H ${s.x} V ${s.y+s.h} H ${s.x+s.w} M ${s.x+90} ${s.y} V ${s.y+s.h}" fill="white" stroke="black" stroke-width="2"/>`);
 vertex('','shape=line;direction=south;strokeColor=#000000;',s.x+90,s.y,1,s.h);text(key,s.x,s.y+12,90,22);text(s.name,s.x+95,s.y+12,s.w-95,21);
}
const users=new Map();for(const [name,y] of [['Administrator',200],['Authorized Staff',1850],['Member / Applicant',3450]]){
 const u={x:2070,y,w:285,h:130};u.id=rect(u.x,u.y,u.w,u.h);text(name,u.x,u.y+46,u.w,24);users.set(name,u);
}
const processes=ps.map((p,i)=>{
 const c={x:1110,y:80+i*450,w:430,h:300};c.id=rect(c.x,c.y,c.w,c.h,true);
 rect(c.x,c.y,c.w,55,false,'#d5e2f5');text(p.Id,c.x,c.y+10,c.w,27);
 let line='',lines=[];for(const word of p.Name.split(' ')){if((line+' '+word).trim().length>25){lines.push(line);line=word}else line=(line+' '+word).trim();}if(line)lines.push(line);
 lines.forEach((t,j)=>text(t,c.x,c.y+108+j*36,c.w,25));return c;
});
function route(s,t,points,label,lx,ly,lw,both=false){
 edges++;const id='e'+(++serial);const first=points[0],last=points.at(-1);
 cells.push(`<mxCell id="${id}" style="edgeStyle=segmentEdgeStyle;rounded=0;strokeColor=#000000;strokeWidth=1.3;endArrow=block;startArrow=${both?'block':'none'};startSize=8;endSize=8;exitX=${(first[0]-s.x)/s.w};exitY=${(first[1]-s.y)/s.h};entryX=${(last[0]-t.x)/t.w};entryY=${(last[1]-t.y)/t.h};exitPerimeter=0;entryPerimeter=0;" edge="1" parent="1" source="${s.id}" target="${t.id}"><mxGeometry relative="1" as="geometry"><Array as="points">${points.slice(1,-1).map(([x,y])=>`<mxPoint x="${x}" y="${y}"/>`).join('')}</Array></mxGeometry></mxCell>`);
 // A white halo separates crossings; no junction dots are implied.
 const d=points.map((p,i)=>(i?'L ':'M ')+p.join(' ')).join(' ');
 svg.push(`<path d="${d}" fill="none" stroke="white" stroke-width="4.5"/><path d="${d}" fill="none" stroke="black" stroke-width="1.3" marker-end="url(#arrow)" ${both?'marker-start="url(#arrow)"':''}/>`);
 text(label,lx,ly,lw,19);
}
let leftLane=0,rightLane=0;const uses=new Map();let represented=0;
const shortStores={D0:'Account / session data',D1:'Profile / role data',D14:'Session ownership data',D2:'Application / review data',D3:'Member details / updates',D8:'Membership change data',D4:'Visit / attendance data',D10:'Pairing policy data',D11:'Pairing session data',D13:'Scan request / result',D5:'Product / stock data',D6:'Transaction data',D7:'Sale item data',D9:'Recorded operation data','D2-D8':'Report source records'};
const shortActors=['Credentials / access result','Application / review result','Account / counter data','Renewal / review result','Attendance / pairing data','Catalog / inventory data','Sale details / results','Report query / output','Log query / results'];
for(let pi=0;pi<9;pi++){
 const p=ps[pi],c=processes[pi];let port=0;
 for(const data of p.Stores){
  const s=stores.get(data[0]),write=!!data[2],read=!!data[3];
  const cy=c.y+65+(++port)*210/(p.Stores.length+1),lane=600+(leftLane++)*7;
  const ordinal=uses.get(data[0])||0;uses.set(data[0],ordinal+1);
  const sy=s.y+7+ordinal*6;
  const pts=[[s.x+s.w,sy],[lane,sy],[lane,cy],[c.x,cy]];
  represented+=Number(write)+Number(read);
  route(read?s:c,read?c:s,read?pts:pts.toReversed(),shortStores[data[0]],885,cy-30,220,write&&read);
 }
 for(let ai=0;ai<actors[pi].length;ai++){
  const [name,input,output]=actors[pi][ai],u=users.get(name);
  const cy=c.y+95+ai*70,lane=1800+(rightLane++)*9;
  const uy=u.y+9+rightLane*3;
  const pts=[[c.x+c.w,cy],[lane,cy],[lane,uy],[u.x,uy]];
  route(c,u,pts,shortActors[pi],1545,cy-30,245,true);represented+=2;
 }
}
text('Two arrowheads represent paired read/write or request/result flows. D2-D8 groups report sources; it is not a new table.',70,4130,2260,23);
writeFileSync(join(dir,'03-dfd-simple.svg'),`<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}"><defs><marker id="arrow" markerWidth="8" markerHeight="6" refX="8" refY="3" orient="auto-start-reverse"><path d="M0 0 L8 3 L0 6 Z"/></marker></defs><rect width="${W}" height="${H}" fill="white"/>${svg.join('')}</svg>`);
writeFileSync(join(dir,'03-dfd-simple.drawio'),`<mxfile host="app.diagrams.net"><diagram id="dfd" name="Level 1 DFD"><mxGraphModel page="1" pageWidth="${W}" pageHeight="${H}"><root><mxCell id="0"/><mxCell id="1" parent="0"/>${cells.join('')}</root></mxGraphModel></diagram></mxfile>`);
if(represented!==96)throw Error('Missing original data flows');
console.log('Exported '+edges+' connectors representing all '+represented+' directional flows; related directions share one clearly marked route.');
