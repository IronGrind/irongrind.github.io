import {readFileSync,writeFileSync} from 'node:fs';
import {dirname,join} from 'node:path';
import {fileURLToPath} from 'node:url';
const dir=join(dirname(fileURLToPath(import.meta.url)),'..','Chapter 3 Diagrams');
const read=n=>JSON.parse(readFileSync(join(dir,n),'utf8').replace(/^\uFEFF/,''));
const es=read('_Sources/05-gym-erd-elements.json'),model=read('schema-visualizer.json');
const esc=s=>String(s).replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;').replaceAll('"','&quot;');
const cw=410,hh=46,rh=30,W=2300,H=1610,cards=new Map();
for(const e of es.filter(e=>e.Tag==='rect'&&e.A.width==='240'&&e.A.fill==='#fff'&&e.A.stroke)){
 const x=+e.A.x,y=+e.A.y,h=+e.A.height;
 const title=es.find(t=>t.Tag==='text'&&+t.A.x===x+120&&+t.A.y===y+20)?.Text;
 if(!title)throw Error('Missing table name');
 const name=title==='auth.users'?title:'public.'+title;
 const fields=es.filter(t=>t.Tag==='text'&&t.A['text-anchor']==='end'&&+t.A.x>x&&+t.A.x<x+240&&+t.A.y>y&&+t.A.y<y+h).map(t=>{
  const f=es.find(f=>f.Tag==='text'&&f.A['font-size']==='12.5'&&f.A.y===t.A.y&&+f.A.x>x&&+f.A.x<+t.A.x);
  if(!f)throw Error('Missing field label');
  const col=name==='auth.users'?{Name:'id',Type:'uuid',Required:true,Keys:['PK']}:model.Tables.find(t=>t.Name===name)?.Columns.find(c=>c.Name===f.Text);
  if(!col||col.Type!==t.Text)throw Error('Field/type mismatch '+name+'.'+f.Text);
  return col;
 });
 cards.set(name,{name,title,fields,w:cw,h:hh+fields.length*rh});
}
const positions={
 'public.profiles':[40,170], 'public.mobile_attendance_pairing_policy':[40,620], 'public.activity_logs':[40,1070],
 'public.membership_applications':[620,183], 'public.members':[620,633], 'public.membership_history':[620,1083],
 'public.attendance':[1200,196], 'public.mobile_attendance_scan_sessions':[1200,646], 'public.mobile_attendance_scan_events':[1200,1096],
 'public.products':[1780,209], 'public.sales':[1780,659], 'public.sale_items':[1780,1109], 'auth.users':[620,1490]
};
for(const c of cards.values()){const pos=positions[c.name];if(!pos)throw Error('Unplaced table');[c.x,c.y]=pos;}
if(cards.size!==13)throw Error('Missing table');
const publicFields=[...cards.values()].filter(c=>c.name!=='auth.users').reduce((n,c)=>n+c.fields.length,0);
if(publicFields!==77)throw Error('Selected field coverage changed');
const row=(c,f)=>{const i=c.fields.findIndex(v=>v.Name===f);if(i<0)throw Error('Key field omitted');return c.y+hh+rh*(i+.5);};
const relations=model.Relations.filter(r=>r.Child.startsWith('public.'));
if(relations.length!==18)throw Error('Wrong relationship count');
const routes=[],gutterUses=new Map(),ports=new Map();let authUse=0,topBus=0;
function lane(gutter){const i=gutterUses.get(gutter)||0;gutterUses.set(gutter,i+1);return 450+gutter*580+45+i*18;}
for(const rel of relations){
 const p=cards.get(rel.Parent),c=cards.get(rel.Child),fk=c.fields.find(f=>f.Name===rel.Field);
 if(!p||!c||!fk)throw Error('Missing relationship endpoint');
 const auth=rel.Parent==='auth.users';let points;
 const cy=row(c,rel.Field)+(routes.length+1)*0.13;
 if(auth){
  const i=authUse++,px=p.x+35+i*41,py=p.y,bus=1390+i*7;
  const col=Math.round((c.x-40)/580),gx=col===0?5+i*0.8:c.x-145+i*12;
  points=[[px,py],[px,bus],[gx,bus],[gx,cy],[c.x,cy]];
 }else{
  const key=rel.Parent+'.'+rel.ParentField,used=ports.get(key)||0;ports.set(key,used+1);
  const degree=relations.filter(r=>r.Parent===rel.Parent&&r.ParentField===rel.ParentField).length;
  const py=row(p,rel.ParentField)+(used-(degree-1)/2)*10+(routes.length+1)*0.17;
  const pc=Math.round((p.x-40)/580),cc=Math.round((c.x-40)/580);
  if(pc===cc){const gx=lane(pc);points=[[p.x+cw,py],[gx,py],[gx,cy],[c.x+cw,cy]];}
  else if(Math.abs(pc-cc)===1){const gx=lane(Math.min(pc,cc));points=pc<cc?[[p.x+cw,py],[gx,py],[gx,cy],[c.x,cy]]:[[p.x,py],[gx,py],[gx,cy],[c.x+cw,cy]];}
  else{const pg=lane(pc),cg=lane(cc-1),bus=65+topBus++*20;points=[[p.x+cw,py],[pg,py],[pg,bus],[cg,bus],[cg,cy],[c.x,cy]];}
 }
 routes.push({rel,auth,points,required:fk.Required,unique:fk.Keys.includes('UQ')||fk.Keys.includes('PK')});
}
// Reject a route through an unrelated card or sharing a track with another route.
const segs=routes.flatMap((r,ri)=>r.points.slice(1).map((b,i)=>({a:r.points[i],b,ri})));
for(const s of segs){for(const c of cards.values()){
 const horizontal=s.a[1]===s.b[1];
 const crosses=horizontal?s.a[1]>c.y&&s.a[1]<c.y+c.h&&Math.min(s.a[0],s.b[0])<c.x+cw&&Math.max(s.a[0],s.b[0])>c.x:s.a[0]>c.x&&s.a[0]<c.x+cw&&Math.min(s.a[1],s.b[1])<c.y+c.h&&Math.max(s.a[1],s.b[1])>c.y;
 if(crosses)throw Error('Route crosses table '+c.name);
}}
for(let i=0;i<segs.length;i++)for(let j=i+1;j<segs.length;j++){
 const a=segs[i],b=segs[j];if(a.ri===b.ri)continue;
 const h=a.a[1]===a.b[1];if(h!==(b.a[1]===b.b[1]))continue;
 const axis=h?0:1,fixed=1-axis;
 if(a.a[fixed]===b.a[fixed]&&Math.min(Math.max(a.a[axis],a.b[axis]),Math.max(b.a[axis],b.b[axis]))>Math.max(Math.min(a.a[axis],a.b[axis]),Math.min(b.a[axis],b.b[axis])))throw Error('Shared relationship segment '+JSON.stringify({a,b}));
}
let serial=0;const cells=[],svg=[];
function vertex(t,style,x,y,w,h,parent='1'){const id='c'+(++serial);cells.push(`<mxCell id="${id}" value="${esc(t)}" style="${style}" vertex="1" parent="${parent}"><mxGeometry x="${x}" y="${y}" width="${w}" height="${h}" as="geometry"/></mxCell>`);return id;}
for(const c of cards.values()){
 c.id=vertex('','group;',c.x,c.y,cw,c.h);
 vertex('','rounded=1;fillColor=#ffffff;strokeColor=#000000;strokeWidth=1.2;',0,0,cw,c.h,c.id);
 vertex('','fillColor=#d5e2f5;strokeColor=#000000;strokeWidth=1.2;',0,0,cw,hh,c.id);
 svg.push(`<rect x="${c.x}" y="${c.y}" width="${cw}" height="${c.h}" rx="8" fill="white" stroke="black" stroke-width="1.2"/><rect x="${c.x}" y="${c.y}" width="${cw}" height="${hh}" fill="#d5e2f5" stroke="black" stroke-width="1.2"/>`);
 function label(t,x,y,w,size,bold=false,align='left'){
  vertex(t,`text;html=0;whiteSpace=wrap;align=${align};verticalAlign=middle;fontFamily=Arial;fontSize=${size};fontStyle=${bold?1:0};spacing=0;`,x,y,w,28,c.id);
  const px=c.x+x+(align==='right'?w:align==='center'?w/2:0),anchor=align==='right'?'end':align==='center'?'middle':'start';
  svg.push(`<text x="${px}" y="${c.y+y+21}" text-anchor="${anchor}" font-family="Arial" font-size="${size}" font-weight="${bold?700:400}">${esc(t)}</text>`);
 }
 label(c.title,5,7,cw-10,18,true,'center');
 c.fields.forEach((f,i)=>{const y=hh+i*rh;label(f.Keys.join('/'),9,y,58,11,true);label(f.Name,76,y,215,16,f.Keys.includes('PK'));label(f.Type,285,y,116,13,false,'right');});
}
function symbol(point,next,many,optional,color){
 const dx=Math.sign(next[0]-point[0]),dy=Math.sign(next[1]-point[1]),nx=-dy,ny=dx;
 const at=(dist,side=0)=>[point[0]+dx*dist+nx*side,point[1]+dy*dist+ny*side];
 const line=(a,b)=>svg.push(`<path d="M ${a.join(' ')} L ${b.join(' ')}" fill="none" stroke="${color}" stroke-width="1.5"/>`);
 if(many){line(at(0,7),at(14));line(at(0,-7),at(14));}else line(at(8,7),at(8,-7));
 if(optional){const p=at(23);svg.push(`<circle cx="${p[0]}" cy="${p[1]}" r="4.5" fill="white" stroke="${color}" stroke-width="1.5"/>`);}else line(at(19,7),at(19,-7));
}
for(const [i,r] of routes.entries()){
 const color=r.auth?'#aab2bd':'#000000',points=r.points,p=cards.get(r.rel.Parent),c=cards.get(r.rel.Child);
 const start=r.required?'ERmandOne':'ERzeroToOne',end=r.unique?'ERzeroToOne':'ERzeroToMany';
 const first=points[0],last=points.at(-1),way=points.slice(1,-1).map(([x,y])=>`<mxPoint x="${x}" y="${y}"/>`).join('');
 cells.push(`<mxCell id="e${i}" value="" style="edgeStyle=segmentEdgeStyle;jumpStyle=arc;jumpSize=5;strokeColor=${color};strokeWidth=${r.auth?1:1.5};dashed=${r.auth?1:0};dashPattern=6 5;startArrow=${start};startFill=0;startSize=10;endArrow=${end};endFill=0;endSize=10;exitX=${(first[0]-p.x)/cw};exitY=${(first[1]-p.y)/p.h};entryX=${(last[0]-c.x)/cw};entryY=${(last[1]-c.y)/c.h};exitPerimeter=0;entryPerimeter=0;" edge="1" parent="1" source="${p.id}" target="${c.id}"><mxGeometry relative="1" as="geometry"><Array as="points">${way}</Array></mxGeometry></mxCell>`);
 const d=points.map((p,j)=>(j?'L ':'M ')+p.join(' ')).join(' ');
 svg.push(`<path d="${d}" fill="none" stroke="white" stroke-width="4"/><path d="${d}" fill="none" stroke="${color}" stroke-width="${r.auth?1:1.5}" ${r.auth?'stroke-dasharray="6 5"':''}><title>${esc(r.rel.Child+'.'+r.rel.Field+' references '+r.rel.Parent+'.'+r.rel.ParentField)}</title></path>`);
 symbol(first,points[1],false,!r.required,color);symbol(last,points.at(-2),!r.unique,true,color);
}
writeFileSync(join(dir,'05-gym-erd-editable.svg'),`<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}"><rect width="${W}" height="${H}" fill="white"/>${svg.join('')}</svg>`);
writeFileSync(join(dir,'05-gym-erd-editable.drawio'),`<mxfile host="app.diagrams.net"><diagram id="erd" name="Database ERD"><mxGraphModel page="1" pageWidth="${W}" pageHeight="${H}"><root><mxCell id="0"/><mxCell id="1" parent="0"/>${cells.join('')}</root></mxGraphModel></diagram></mxfile>`);
console.log('Verified 12 public tables + Auth reference, 77 selected public fields, and all 18 foreign keys. No connector passes through a card or shares a line segment.');
