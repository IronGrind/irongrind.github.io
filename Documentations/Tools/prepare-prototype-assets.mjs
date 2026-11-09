import {readFileSync,writeFileSync,mkdirSync} from 'node:fs';
import {dirname,join} from 'node:path';
import {fileURLToPath} from 'node:url';
import {figures,sections} from './prototype-content.mjs';
import {overviewText,selectedDetails} from './prototype-whole-overviews.mjs';
const base=join(dirname(fileURLToPath(import.meta.url)),'..','Prototype Screenshots');
const originals=JSON.parse(readFileSync(join(base,'_Sources','screenshots.json'),'utf8').replace(/^\uFEFF/,''));
mkdirSync(join(base,'Figures'),{recursive:true});
if(figures.length!==27||new Set(figures.map(f=>f.id)).size!==27||originals.length!==27)throw Error('Screenshot coverage mismatch');
const output=[];const index=['# Prototype figure index','','Every main figure shows a complete original screenshot. Lettered figures are supplementary enlarged details of the three long registration forms.','','| Figure | Interface | Source capture |','|---|---|---|'];
for(const [i,f] of figures.entries()){
 const source=originals.find(s=>s.Id===f.id);if(!source)throw Error('Missing source');
 const number=6+i;
 const details=selectedDetails[f.id];
 const parts=[{text:overviewText[f.id]||f.text,kind:'whole'},...(details?f.parts.map((p,j)=>({...p,text:details[j],kind:'detail'})):[])];
 if(!parts[0].text)throw Error('Missing complete-screenshot explanation');
 if(details&&details.length!==f.parts.length)throw Error('Detail description mismatch');
 for(const [pi,p] of parts.entries()){
  const suffix=p.kind==='detail'?String.fromCharCode(96+pi):'';
  const label=number+suffix;
  const caption='Figure '+label+'. '+f.title+(p.label?' - Enlarged detail: '+p.label:'');
  const file=p.kind==='detail'?join(base,'Figures',label+'-'+f.id+'.png'):source.Path;
  output.push({Number:number,Suffix:suffix,Label:label,Kind:p.kind,Section:f.section,Title:f.title,Caption:caption,Description:p.text,SourceId:f.id,SourcePath:source.Path,ImagePath:file,Crop:p.span?{X:0,Y:p.span[0],Width:source.Width,Height:p.span[1]-p.span[0]}:null,Width:source.Width,Height:p.span?p.span[1]-p.span[0]:source.Height});
  index.push('| '+label+' | '+f.title+(p.label?' ('+p.label+')':'')+' | '+source.ZipPath+' |');
 }
}
const data={Sections:sections.map((s,i)=>({Id:i,Name:s.name,Introduction:s.intro})),Figures:output,SourceCount:27,MainFigureCount:27,OverviewCount:27,DetailCount:8,ImageCount:35,FirstFigure:6,LastFigure:32,GanttFigure:33};
writeFileSync(join(base,'_Sources','prototype-layout.json'),JSON.stringify(data,null,2));
writeFileSync(join(base,'Figure Index.md'),index.join('\n')+'\n');
if(output.filter(f=>f.Kind==='whole').length!==27||output.filter(f=>f.Kind==='detail').length!==8)throw Error('Overview/detail coverage mismatch');
console.log('Prepared 27 whole-screenshot main figures and 8 selected enlarged details. Main numbering remains 6-32; Gantt remains Figure 33.');
