import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import { deflateRawSync } from 'node:zlib';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const out=path.join(root,'Documentations/Defense');fs.mkdirSync(out,{recursive:true});
const esc=s=>String(s).replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;').replaceAll('"','&quot;');
const sourceMap=['# Source Code Map','','Generated from current source definitions. Use alongside the module explanations in Capstone Study and Defense Notes.md. Named functions are navigation points, not a line-by-line correctness certification. Inline callbacks and generated SQL patches require reading their surrounding module.','','## Browser and development modules',''];
for(const relative of [...fs.readdirSync(path.join(root,'assets/js')).filter(f=>f.endsWith('.js')).map(f=>'assets/js/'+f),'server.js','attendance-phone-sw.js']) {
 const source=fs.readFileSync(path.join(root,relative),'utf8'),lines=source.split(/\r?\n/);
 sourceMap.push(`### ${relative}`,'',`[Open source](../../${relative})`,'','| Function / exported handler | Line |','|---|---:|');
 let count=0;
 lines.forEach((line,i)=>{
  const match=line.match(/(?:async\s+)?function\s+([\w$]+)\s*\(/)||line.match(/window\.([\w$]+)\s*=\s*(?:async\s*)?(?:\([^)]*\)|\w+)\s*=>/);
  if(match){sourceMap.push(`| ${match[1]} | ${i+1} |`);count++;}
 });
 if(!count)sourceMap.push('| Module initialization and event handlers; read source | 1 |');
 sourceMap.push('');
}
sourceMap.push('## Edge Functions','','| Function folder | Entrypoint / responsibility |','|---|---|');
for(const folder of fs.readdirSync(path.join(root,'supabase/functions'),{withFileTypes:true}).filter(d=>d.isDirectory())) {
 const files=fs.readdirSync(path.join(root,'supabase/functions',folder.name)).filter(f=>f.endsWith('.ts'));
 sourceMap.push(`| ${folder.name} | ${files.map(f=>`[${f}](../../supabase/functions/${folder.name}/${f})`).join(', ')} |`);
}
sourceMap.push('','## SQL routine definitions','','A routine may be replaced or patched by a later migration. This lists the latest explicit CREATE FUNCTION occurrence, not the final live pg_get_functiondef result. Use migration order and SQL tests to understand later patches.','','| Routine | Latest explicit source definition |','|---|---|');
const routines=new Map();
for(const file of fs.readdirSync(path.join(root,'supabase/migrations')).filter(f=>f.endsWith('.sql')).sort()) {
 const sql=fs.readFileSync(path.join(root,'supabase/migrations',file),'utf8');
 for(const match of sql.matchAll(/create\s+(?:or\s+replace\s+)?function\s+("?[\w]+"?\."?[\w]+"?)\s*\(/gi)) {
  const name=match[1].replaceAll('"',''); const line=sql.slice(0,match.index).split('\n').length;
  routines.set(name,`${file}:${line}`);
 }
}
for(const [name,location] of [...routines].sort((a,b)=>a[0].localeCompare(b[0])))sourceMap.push(`| ${name} | ${location} |`);
fs.writeFileSync(path.join(out,'Source Code Map.md'),sourceMap.join('\n')+'\n');

// Use PowerPoint's native writer for the editable deck. The former hand-built
// Open XML package passed basic ZIP/XML checks but PowerPoint rejected it.
const nativeBuild = spawnSync('powershell.exe', ['-NoProfile','-ExecutionPolicy','Bypass','-File',path.join(root,'Documentations/Tools/build-defense-presentation.ps1')], {stdio:'inherit', windowsHide:true});
if (nativeBuild.error) throw nativeBuild.error;
if (nativeBuild.status !== 0) throw new Error(`Native PowerPoint generation failed with exit code ${nativeBuild.status}.`);
process.exit(0);

const markdown=fs.readFileSync(path.join(out,'Capstone Presentation.md'),'utf8');
const slides=[...markdown.matchAll(/^## Slide (\d+) — (.+)\r?\n([\s\S]*?)(?=^## |$(?![\s\S]))/gm)].map(match=>{
 const body=match[3],notes=body.split('Speaker notes:')[1]?.trim()||'';
 return {title:match[2],bullets:[...body.split('Speaker notes:')[0].matchAll(/^- (.+)$/gm)].map(m=>m[1]),notes};
});
const expectedSlides=[...markdown.matchAll(/^## Slide \d+ /gm)].length;
if(!slides.length||slides.length!==expectedSlides||slides.some(s=>!s.notes||!s.bullets.length))throw Error('Incomplete slide/speaker-note source or malformed slide heading');
const P='http://schemas.openxmlformats.org/presentationml/2006/main',A='http://schemas.openxmlformats.org/drawingml/2006/main',R='http://schemas.openxmlformats.org/officeDocument/2006/relationships';
const relType='http://schemas.openxmlformats.org/officeDocument/2006/relationships/';
const head='<?xml version="1.0" encoding="UTF-8" standalone="yes"?>';
const rels=items=>head+'<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'+items.map(([id,type,target])=>`<Relationship Id="${id}" Type="${relType+type}" Target="${target}"/>`).join('')+'</Relationships>';
const paragraphs=(texts,size,color='202938')=>texts.map(text=>`<a:p><a:pPr marL="0" indent="0"><a:spcAft><a:spcPts val="1400"/></a:spcAft></a:pPr><a:r><a:rPr lang="en-US" sz="${size}"><a:solidFill><a:srgbClr val="${color}"/></a:solidFill><a:latin typeface="Arial"/></a:rPr><a:t>${esc(text)}</a:t></a:r><a:endParaRPr lang="en-US"/></a:p>`).join('');
const textBox=(id,name,x,y,cx,cy,texts,size,color)=>`<p:sp><p:nvSpPr><p:cNvPr id="${id}" name="${name}"/><p:cNvSpPr txBox="1"/><p:nvPr/></p:nvSpPr><p:spPr><a:xfrm><a:off x="${x}" y="${y}"/><a:ext cx="${cx}" cy="${cy}"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom><a:noFill/><a:ln><a:noFill/></a:ln></p:spPr><p:txBody><a:bodyPr wrap="square"/><a:lstStyle/>${paragraphs(texts,size,color)}</p:txBody></p:sp>`;
const group='<p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>';
const colorMap='<p:clrMap accent1="accent1" accent2="accent2" accent3="accent3" accent4="accent4" accent5="accent5" accent6="accent6" bg1="lt1" bg2="lt2" folHlink="folHlink" hlink="hlink" tx1="dk1" tx2="dk2"/>';
const files=new Map();const put=(name,data)=>files.set(name,Buffer.from(data));
put('_rels/.rels',rels([['rId1','officeDocument','ppt/presentation.xml']]));
put('ppt/presentation.xml',head+`<p:presentation xmlns:p="${P}" xmlns:a="${A}" xmlns:r="${R}"><p:sldMasterIdLst><p:sldMasterId id="2147483648" r:id="rIdMaster"/></p:sldMasterIdLst><p:notesMasterIdLst><p:notesMasterId r:id="rIdNotes"/></p:notesMasterIdLst><p:sldIdLst>${slides.map((_,i)=>`<p:sldId id="${256+i}" r:id="rId${i+1}"/>`).join('')}</p:sldIdLst><p:sldSz cx="12192000" cy="6858000" type="screen16x9"/><p:notesSz cx="6858000" cy="9144000"/></p:presentation>`);
put('ppt/_rels/presentation.xml.rels',rels([['rIdMaster','slideMaster','slideMasters/slideMaster1.xml'],['rIdNotes','notesMaster','notesMasters/notesMaster1.xml'],...slides.map((_,i)=>[`rId${i+1}`,'slide',`slides/slide${i+1}.xml`])]));
put('ppt/slideMasters/slideMaster1.xml',head+`<p:sldMaster xmlns:p="${P}" xmlns:a="${A}" xmlns:r="${R}"><p:cSld><p:spTree>${group}</p:spTree></p:cSld>${colorMap}<p:sldLayoutIdLst><p:sldLayoutId id="2147483649" r:id="rId1"/></p:sldLayoutIdLst><p:txStyles><p:titleStyle/><p:bodyStyle/><p:otherStyle/></p:txStyles></p:sldMaster>`);
put('ppt/slideMasters/_rels/slideMaster1.xml.rels',rels([['rId1','slideLayout','../slideLayouts/slideLayout1.xml'],['rId2','theme','../theme/theme1.xml']]));
put('ppt/slideLayouts/slideLayout1.xml',head+`<p:sldLayout xmlns:p="${P}" xmlns:a="${A}" xmlns:r="${R}" type="blank" preserve="1"><p:cSld name="Blank"><p:spTree>${group}</p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sldLayout>`);
put('ppt/slideLayouts/_rels/slideLayout1.xml.rels',rels([['rId1','slideMaster','../slideMasters/slideMaster1.xml']]));
const colors={dk1:'202938',lt1:'FFFFFF',dk2:'414B5B',lt2:'F5F6F8',accent1:'8B0000',accent2:'54749D',accent3:'3F7C62',accent4:'B1863D',accent5:'765887',accent6:'607782',hlink:'8B0000',folHlink:'765887'};
const solid='<a:solidFill><a:schemeClr val="phClr"/></a:solidFill>';
put('ppt/theme/theme1.xml',head+`<a:theme xmlns:a="${A}" name="IronGrind"><a:themeElements><a:clrScheme name="IronGrind">${Object.entries(colors).map(([key,color])=>`<a:${key}><a:srgbClr val="${color}"/></a:${key}>`).join('')}</a:clrScheme><a:fontScheme name="Arial"><a:majorFont><a:latin typeface="Arial"/><a:ea typeface=""/><a:cs typeface=""/></a:majorFont><a:minorFont><a:latin typeface="Arial"/><a:ea typeface=""/><a:cs typeface=""/></a:minorFont></a:fontScheme><a:fmtScheme name="IronGrind"><a:fillStyleLst>${solid.repeat(3)}</a:fillStyleLst><a:lnStyleLst>${`<a:ln w="12700">${solid}<a:prstDash val="solid"/></a:ln>`.repeat(3)}</a:lnStyleLst><a:effectStyleLst>${'<a:effectStyle><a:effectLst/></a:effectStyle>'.repeat(3)}</a:effectStyleLst><a:bgFillStyleLst>${solid.repeat(3)}</a:bgFillStyleLst></a:fmtScheme></a:themeElements></a:theme>`);
put('ppt/notesMasters/notesMaster1.xml',head+`<p:notesMaster xmlns:p="${P}" xmlns:a="${A}" xmlns:r="${R}"><p:cSld><p:spTree>${group}</p:spTree></p:cSld>${colorMap}<p:notesStyle/></p:notesMaster>`);
put('ppt/notesMasters/_rels/notesMaster1.xml.rels',rels([['rId1','theme','../theme/theme1.xml']]));
slides.forEach((slide,i)=>{
 const num=i+1;
 put(`ppt/slides/slide${num}.xml`,head+`<p:sld xmlns:p="${P}" xmlns:a="${A}" xmlns:r="${R}"><p:cSld><p:bg><p:bgPr><a:solidFill><a:srgbClr val="FFFFFF"/></a:solidFill><a:effectLst/></p:bgPr></p:bg><p:spTree>${group}${textBox(2,'Title',600000,420000,10900000,900000,[slide.title],3200,'8B0000')}${textBox(3,'Content',700000,1600000,10600000,4200000,slide.bullets.map(text=>'• '+text),2400,'202938')}${textBox(4,'Footer',700000,6250000,10600000,300000,[`IronGrind  |  Defense draft — verify deployment and screenshots  |  ${num} / ${slides.length}`],1000,'657184')}</p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sld>`);
 put(`ppt/slides/_rels/slide${num}.xml.rels`,rels([['rId1','slideLayout','../slideLayouts/slideLayout1.xml'],['rId2','notesSlide',`../notesSlides/notesSlide${num}.xml`]]));
 const notesShape=`<p:sp><p:nvSpPr><p:cNvPr id="2" name="Notes"/><p:cNvSpPr/><p:nvPr><p:ph type="body" idx="1"/></p:nvPr></p:nvSpPr><p:spPr/><p:txBody><a:bodyPr/><a:lstStyle/>${paragraphs([slide.notes],1200)}</p:txBody></p:sp>`;
 put(`ppt/notesSlides/notesSlide${num}.xml`,head+`<p:notes xmlns:p="${P}" xmlns:a="${A}" xmlns:r="${R}"><p:cSld><p:spTree>${group}${notesShape}</p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:notes>`);
 put(`ppt/notesSlides/_rels/notesSlide${num}.xml.rels`,rels([['rId1','notesMaster','../notesMasters/notesMaster1.xml'],['rId2','slide',`../slides/slide${num}.xml`]]));
});
const ct='application/vnd.openxmlformats-officedocument.presentationml.';
const types=[['/ppt/presentation.xml',ct+'presentation.main+xml'],['/ppt/slideMasters/slideMaster1.xml',ct+'slideMaster+xml'],['/ppt/slideLayouts/slideLayout1.xml',ct+'slideLayout+xml'],['/ppt/notesMasters/notesMaster1.xml',ct+'notesMaster+xml'],['/ppt/theme/theme1.xml','application/vnd.openxmlformats-officedocument.theme+xml'],...slides.flatMap((_,i)=>[[`/ppt/slides/slide${i+1}.xml`,ct+'slide+xml'],[`/ppt/notesSlides/notesSlide${i+1}.xml`,ct+'notesSlide+xml']])];
put('[Content_Types].xml',head+'<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/>'+types.map(([name,type])=>`<Override PartName="${name}" ContentType="${type}"/>`).join('')+'</Types>');
// Small deterministic ZIP writer; all presentation parts are UTF-8 XML.
const crc=buffer=>{let crc=0xffffffff;for(const byte of buffer){crc^=byte;for(let i=0;i<8;i++)crc=(crc>>>1)^((crc&1)?0xedb88320:0);}return (crc^0xffffffff)>>>0;};
const locals=[],central=[];let offset=0;
for(const [name,data] of files){
 const filename=Buffer.from(name),packed=deflateRawSync(data),checksum=crc(data),local=Buffer.alloc(30),directory=Buffer.alloc(46);
 local.writeUInt32LE(0x04034b50,0);local.writeUInt16LE(20,4);local.writeUInt16LE(0x800,6);local.writeUInt16LE(8,8);local.writeUInt32LE(checksum,14);local.writeUInt32LE(packed.length,18);local.writeUInt32LE(data.length,22);local.writeUInt16LE(filename.length,26);
 directory.writeUInt32LE(0x02014b50,0);directory.writeUInt16LE(20,4);directory.writeUInt16LE(20,6);directory.writeUInt16LE(0x800,8);directory.writeUInt16LE(8,10);directory.writeUInt32LE(checksum,16);directory.writeUInt32LE(packed.length,20);directory.writeUInt32LE(data.length,24);directory.writeUInt16LE(filename.length,28);directory.writeUInt32LE(offset,42);
 locals.push(local,filename,packed);central.push(directory,filename);offset+=local.length+filename.length+packed.length;
}
const directories=Buffer.concat(central),end=Buffer.alloc(22);end.writeUInt32LE(0x06054b50,0);end.writeUInt16LE(files.size,8);end.writeUInt16LE(files.size,10);end.writeUInt32LE(directories.length,12);end.writeUInt32LE(offset,16);
fs.writeFileSync(path.join(out,'Capstone Presentation.pptx'),Buffer.concat([...locals,directories,end]));
console.log(`Generated source map and editable ${slides.length}-slide PowerPoint with ${slides.length} speaker-note sections.`);
