import {readFileSync,writeFileSync,mkdirSync} from 'node:fs';
import {dirname,join} from 'node:path';
import {fileURLToPath} from 'node:url';
import {figures,sections} from './prototype-content.mjs';
const base=join(dirname(fileURLToPath(import.meta.url)),'..','Prototype Screenshots');
const originals=JSON.parse(readFileSync(join(base,'_Sources','screenshots.json'),'utf8').replace(/^\uFEFF/,''));
mkdirSync(join(base,'Figures'),{recursive:true});
if(figures.length!==27||new Set(figures.map(f=>f.id)).size!==27||originals.length!==27)throw Error('Screenshot coverage mismatch');
const output=[];const index=['# Prototype figure index','','These are the supplied interface captures used in Chapter 3. Original captures remain under Originals; Figures contains only the readable parts of long captures.','','| Figure | Interface | Source capture |','|---|---|---|'];
for(const [i,f] of figures.entries()){
 const source=originals.find(s=>s.Id===f.id);if(!source)throw Error('Missing source');
 const number=6+i;const parts=f.parts||[{text:f.text}];
 if(f.parts){let covered=0;for(const p of parts){if(p.span[0]>covered||p.span[0]<0||p.span[1]>source.Height||p.span[1]<=p.span[0])throw Error('Invalid crop coverage');covered=Math.max(covered,p.span[1]);}if(covered!==source.Height)throw Error('A capture area was omitted');}
 for(const [pi,p] of parts.entries()){
  const suffix=f.parts?String.fromCharCode(97+pi):'';
  const label=number+suffix;
  const caption='Figure '+label+'. '+f.title+(p.label?' - '+p.label:'');
  const file=f.parts?join(base,'Figures',label+'-'+f.id+'.png'):source.Path;
  output.push({Number:number,Suffix:suffix,Label:label,Section:f.section,Title:f.title,Caption:caption,Description:p.text,SourceId:f.id,SourcePath:source.Path,ImagePath:file,Crop:p.span?{X:0,Y:p.span[0],Width:source.Width,Height:p.span[1]-p.span[0]}:null,Width:source.Width,Height:p.span?p.span[1]-p.span[0]:source.Height});
  index.push('| '+label+' | '+f.title+(p.label?' ('+p.label+')':'')+' | '+source.ZipPath+' |');
 }
}
const data={Sections:sections.map((s,i)=>({Id:i,Name:s.name,Introduction:s.intro})),Figures:output,SourceCount:27,MainFigureCount:27,FirstFigure:6,LastFigure:32,GanttFigure:33};
writeFileSync(join(base,'_Sources','prototype-layout.json'),JSON.stringify(data,null,2));
writeFileSync(join(base,'Figure Index.md'),index.join('\n')+'\n');
console.log(`Prepared 27 original captures as ${output.length} readable figure parts, numbered 6-32. Existing Gantt figure will become Figure 33.`);
