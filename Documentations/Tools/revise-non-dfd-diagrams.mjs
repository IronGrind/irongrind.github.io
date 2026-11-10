import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const dir=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../Chapter 3 Diagrams');
const esc=s=>s.replaceAll('&','&amp;').replaceAll('<','&lt;');
const text=(x,y,lines,size=28,anchor='start',bold=false)=>`<text x="${x}" y="${y}" text-anchor="${anchor}" font-family="Arial" font-size="${size}" font-weight="${bold?700:400}" fill="#182536">${lines.map((s,i)=>`<tspan x="${x}" dy="${i?size*1.25:0}">${esc(s)}</tspan>`).join('')}</text>`;
const box=(x,y,w,h,lines)=>`<rect x="${x}" y="${y}" width="${w}" height="${h}" fill="#d8e4f5" stroke="#40546c" stroke-width="3"/>${text(x+w/2,y+h/2-(lines.length-1)*19+10,lines,36,'middle',true)}`;
const line=(x1,y1,x2,y2)=>`<path d="M ${x1} ${y1} L ${x2} ${y2}" stroke="#40546c" stroke-width="3" marker-end="url(#arrow)" fill="none"/>`;
const svg=(w,h,body)=>`<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}"><rect width="${w}" height="${h}" fill="white"/>${body}</svg>`;
let context=`<defs><marker id="arrow" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="9" markerHeight="9" orient="auto-start-reverse"><path d="M 0 0 L 10 5 L 0 10 z" fill="#40546c"/></marker></defs>`;
context+=box(35,420,305,180,['Member /','Applicant']);
context+=box(2040,70,325,170,['Administrator']);
context+=box(2040,755,325,170,['Authorized','Staff']);
context+='<rect x="910" y="300" width="550" height="390" rx="20" fill="white" stroke="#40546c" stroke-width="3"/><path d="M 930 300 H 1440 Q 1460 300 1460 320 V 365 H 910 V 320 Q 910 300 930 300" fill="#d8e4f5"/><path d="M 910 365 H 1460" stroke="#40546c" stroke-width="3"/>';
context+=text(1185,345,['0'],34,'middle')+text(1185,475,['IronGrind Membership and','Operations Management','System'],35,'middle',true);
context+=line(340,455,910,455)+line(910,565,340,565);
context+=text(375,365,['Credentials, registration details,','renewal requests, and permitted','own-profile changes'],28);
context+=text(375,605,['Sign-in and application results; own','membership, QR, attendance history,','and product catalog'],28);
context+=line(2040,205,1460,205)+line(1460,275,2040,275)+line(1460,205,1460,320);
context+=text(1500,65,['Credentials; application / renewal decisions;','membership, inventory, and sales entries;','staff / device controls; report / log queries'],27);
context+=text(1500,315,['Access and operation results; member,','staff, and device status; reports and logs'],27);
context+=line(2040,785,1460,785)+line(1460,870,2040,870)+line(1460,785,1460,630)+line(1460,660,1460,870);
// Split vertical routes avoid a shared line: each arrow remains role- and direction-specific.
context=context.replace('M 1460 660 L 1460 870','M 1490 660 L 1490 870').replace('M 1460 870 L 2040 870','M 1490 870 L 2040 870');
context+=line(1460,660,1490,660);
context+=text(1515,700,['Credentials; counter membership details;','request-review decisions; QR / attendance','identifiers; product-sale entries'],27);
context+=text(1515,915,['Access and task results; permitted attendance','records and the operator\'s own product sales'],27);
context+=text(35,1030,['Walk-in customers transact through an operator. Payments are recorded at the gym.','The system boundary includes authentication and storage; this view shows external information exchange.'],26);
fs.writeFileSync(path.join(dir,'02-context.svg'),svg(2400,1100,context));

// Preserve all ten original date ranges and activity descriptions; omit tiny day-by-day ticks.
const rows=[
 ['Planning','Aug 24–28','Plan the project and identify a potential client.'],
 ['Planning','Sep 2–4','Conduct the first client interview and identify needs and desired features.'],
 ['Planning','Sep 7–11','Present the draft proposal and gather client feedback.'],
 ['Planning','Sep 14–18','Confirm requirements with the client and finalize development features.'],
 ['Design','Sep 21–25','Create the initial interface design and start Chapter 1.'],
 ['Design','Sep 28–Oct 2','Develop prototypes and provide progress updates to the client.'],
 ['Design','Oct 5–9','Improve the interface using client feedback.'],
 ['Design','Oct 12–16','Refine the interface and start Chapter 2.'],
 ['Development','Oct 19–23','Start the backend, database, API, and supporting components.'],
 ['Development','Oct 26–28','Continue frontend and backend work while completing Chapters 1–3.']
];
let gantt=text(45,65,['IRONGRIND — ORIGINAL PLANNED SCHEDULE (2026)'],40,'start',true);
gantt+=text(45,115,['August 24–October 28 • Ten planned weeks • Bars indicate scheduled work, not verified completion'],27);
const left=1050,cw=128,top=250,rh=104;
gantt+=text(45,215,['Phase / activity'],29,'start',true)+text(820,215,['Planned dates'],29,'middle',true);
rows.forEach((row,i)=>{const y=top+i*rh;const color=i<4?'#e8eff9':i<8?'#f1eef9':'#e7f1ec';gantt+=`<rect x="35" y="${y}" width="2300" height="${rh}" fill="${color}" stroke="#bcc6d1"/>`;gantt+=text(50,y+32,[`${i+1}. ${row[0]}`],27,'start',true);const words=row[2].split(' ');let lines=[''];for(const word of words){let j=lines.length-1;if((lines[j]+' '+word).trim().length>56){lines.push(word)}else lines[j]=(lines[j]+' '+word).trim()}gantt+=text(50,y+65,lines,24);gantt+=text(825,y+58,[row[1]],26,'middle');for(let j=0;j<=10;j++)gantt+=`<path d="M ${left+j*cw} ${y} v ${rh}" stroke="#bcc6d1"/>`;gantt+=`<rect x="${left+i*cw+15}" y="${y+30}" width="${cw-30}" height="44" rx="9" fill="${i<4?'#476b99':i<8?'#75629b':'#46795b'}"/>`;});
rows.forEach((r,i)=>{gantt+=text(left+i*cw+cw/2,205,[`Week ${i+1}`],25,'middle',true)});
gantt+=text(45,1345,['Planning: Weeks 1–4   |   Design: Weeks 5–8   |   Development: Weeks 9–10'],27);
gantt+=text(45,1400,['The original plan is retained for traceability. Later revisions and deployment evidence are documented separately.'],26);
fs.writeFileSync(path.join(dir,'33-gantt.svg'),svg(2400,1450,gantt));

// Change only the visibility of managed-Auth relationships; preserve their geometry and cardinality.
for(const name of ['05-gym-erd-editable.svg','05-gym-erd-editable.drawio']){
 const file=path.join(dir,name);let source=fs.readFileSync(file,'utf8');
 source=source.replaceAll('#aab2bd','#52657c').replaceAll('#c0c8d4','#52657c');
 fs.writeFileSync(file,source);
}
console.log('Prepared context, original-plan Gantt and darker public ERD sources; Agile and DFD untouched.');
