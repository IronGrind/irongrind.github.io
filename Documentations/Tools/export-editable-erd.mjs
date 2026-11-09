import {readFileSync,writeFileSync} from 'node:fs';
import {dirname,join} from 'node:path';
import {fileURLToPath} from 'node:url';
const out=join(dirname(fileURLToPath(import.meta.url)),'..','Chapter 3 Diagrams');
const es=JSON.parse(readFileSync(join(out,'_Sources','05-gym-erd-elements.json'),'utf8').replace(/^\uFEFF/,''));
const esc=s=>String(s).replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;').replaceAll('"','&quot;');
let serial=0;const cells=[];
const cell=(value,style,geometry,parent='1',extra='')=>{const id='e'+(++serial);cells.push(`<mxCell id="${id}" value="${esc(value)}" style="${esc(style)}" parent="${parent}" ${extra}>${geometry}</mxCell>`);return id;};
const geo=(x,y,w,h)=>`<mxGeometry x="${x}" y="${y}" width="${w}" height="${h}" as="geometry"/>`;
const cards=es.filter(e=>e.Tag==='rect'&&e.A.width==='240'&&e.A.fill==='#fff'&&e.A.stroke);
if(cards.length!==13)throw Error('Expected 12 public tables and Auth reference');
for(const c of cards){c.x=+c.A.x;c.y=+c.A.y;c.w=240;c.h=+c.A.height;c.id=cell('','group;',geo(c.x,c.y,c.w,c.h),'1','vertex="1" connectable="0"');}
const owner=(x,y)=>cards.find(c=>x>=c.x&&x<=c.x+c.w&&y>=c.y&&y<=c.y+c.h);
// Each table is a movable group of native rectangles and editable text cells.
for(const e of es){
 const a=e.A;
 if(e.Tag==='rect'){
  if(a.opacity||(!a.x&&!a.y))continue;
  const x=+(a.x||0),y=+(a.y||0),w=+a.width,h=+a.height,c=owner(x+1,y+1);
  cell('',`rounded=${a.rx?1:0};arcSize=8;fillColor=${a.fill||'none'};strokeColor=${a.stroke||'none'};strokeWidth=${a['stroke-width']||1};`,geo(x-(c?.x||0),y-(c?.y||0),w,h),c?.id||'1','vertex="1"');
 }else if(e.Tag==='text'){
  const x=+a.x,y=+a.y,size=+(a['font-size']||12),c=owner(x,y);
  const end=a['text-anchor']==='end',middle=a['text-anchor']==='middle';
  const w=middle&&c?c.w:(end?105:Math.max(28,e.Text.length*size*.59+5));
  const left=middle?x-w/2:end?x-w:x;
  cell(e.Text,`text;html=0;whiteSpace=wrap;overflow=visible;align=${end?'right':middle?'center':'left'};verticalAlign=middle;spacing=0;fontFamily=Arial;fontSize=${size};fontColor=${a.fill||'#0f172a'};fontStyle=${a['font-weight']==='700'?1:0};`,geo(left-(c?.x||0),y-size-(c?.y||0),w,size*1.25),c?.id||'1','vertex="1"');
 }else if(e.Tag==='path'&&a.d.includes(' Q ')){
  // Native header rectangle, corresponding to the SVG's rounded header path.
  const m=a.d.match(/^M ([\d.]+) ([\d.]+)/);if(!m)continue;
  const c=cards.find(c=>c.x===+m[1]&&c.y+30===+m[2]);if(!c)continue;
  cell('',`rounded=0;fillColor=${a.fill};strokeColor=none;`,geo(0,0,240,30),c.id,'vertex="1"');
 }
}
// Preserve the SVG paint order: card background, header, then editable labels.
const paths=es.filter(e=>e.Tag==='path'&&e.A.fill==='none');
if(paths.length!==18)throw Error('Expected 18 foreign-key relationships');
const labels=['reviewed_by','application_id','member_id','member_id','member_id','member_id','sale_id','product_id','session_id'];
const start=['ERzeroToOne','ERzeroToOne','ERzeroToOne','ERzeroToOne','ERmandOne','ERmandOne','ERmandOne','ERzeroToOne','ERmandOne'];
for(let i=0;i<paths.length;i++){
 const ns=paths[i].A.d.match(/-?\d+(?:\.\d+)?/g).map(Number);const ps=[];for(let j=0;j<ns.length;j+=2)ps.push({x:ns[j],y:ns[j+1]});
 const first=ps[0],last=ps.at(-1),s=owner(first.x,first.y),t=owner(last.x,last.y);if(!s||!t)throw Error('Unattached connector');
 const way=ps.slice(1,-1).map(p=>`<mxPoint x="${p.x}" y="${p.y}"/>`).join('');
 const auth=paths[i].A['data-auth']==='true';
 const startMarker=auth?(paths[i].A['data-required']==='True'?'ERmandOne':'ERzeroToOne'):start[i];
 const endMarker=auth?(paths[i].A['data-unique']==='True'?'ERzeroToOne':'ERzeroToMany'):(i===1?'ERzeroToOne':'ERzeroToMany');
 cell('',`edgeStyle=segmentEdgeStyle;rounded=0;html=0;strokeColor=${auth?'#aab2bd':'#000000'};strokeWidth=${auth?1.2:1.8};dashed=${auth?1:0};dashPattern=6 5;startArrow=${startMarker};startFill=0;startSize=12;endArrow=${endMarker};endFill=0;endSize=12;exitX=${(first.x-s.x)/s.w};exitY=${(first.y-s.y)/s.h};exitPerimeter=0;entryX=${(last.x-t.x)/t.w};entryY=${(last.y-t.y)/t.h};entryPerimeter=0;`, `<mxGeometry relative="1" as="geometry"><Array as="points">${way}</Array></mxGeometry>`,'1',`edge="1" source="${s.id}" target="${t.id}"`);
}
// Native legend symbols, independent of the relationship edge markers.
for(const e of es){const a=e.A;if(e.Tag==='line'&&+a.x1>=1400&&+a.y1>=620){cell('','strokeColor=#000000;endArrow=none;',`<mxGeometry relative="1" as="geometry"><mxPoint x="${a.x1}" y="${a.y1}" as="sourcePoint"/><mxPoint x="${a.x2}" y="${a.y2}" as="targetPoint"/></mxGeometry>`,'1','edge="1"');}else if(e.Tag==='circle'&&+a.cx>=1400&&+a.cy>=620){cell('','ellipse;fillColor=#ffffff;strokeColor=#000000;',geo(+a.cx-+a.r,+a.cy-+a.r,+a.r*2,+a.r*2),'1','vertex="1"');}}
const xml=`<?xml version="1.0" encoding="UTF-8"?><mxfile host="app.diagrams.net"><diagram id="irongrind" name="IronGrind ERD"><mxGraphModel dx="1700" dy="950" grid="1" gridSize="10" guides="1" tooltips="1" connect="1" arrows="1" page="1" pageScale="1" pageWidth="1700" pageHeight="950"><root><mxCell id="0"/><mxCell id="1" parent="0"/>${cells.join('')}</root></mxGraphModel></diagram></mxfile>`;
writeFileSync(join(out,'05-gym-erd-editable.drawio'),xml);
console.log(`Exported 12 public tables, Auth reference, and 18 attached connectors (${serial} native cells).`);
