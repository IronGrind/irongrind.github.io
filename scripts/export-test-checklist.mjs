import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';

const input = 'C:/Users/mycah/.codex/attachments/b0306763-2a5d-48c0-bd47-41ea74485961/Pasted text.txt';
const output = 'Documentations/Testing/Iron Grind End-to-End Manual Testing Checklist - Final.docx';
const source = fs.readFileSync(input, 'utf8').replace(/\r/g, '').split('\n');
const start = source.findIndex(line => line.startsWith('Here is a start-to-end manual testing checklist'));
const end = source.findIndex((line, i) => i > start && line.startsWith('Use this result format:'));
if (start < 0 || end < 0) throw new Error('Could not find the complete checklist in the supplied handoff.');
const lines = source.slice(start, end);
const intro = lines.slice(0, lines.findIndex(line => /^1\. /.test(line))).filter(Boolean);
const sections = [];
let current;
for (const line of lines) {
  const heading = line.match(/^(\d+)\. (.+)$/);
  if (heading) {
    current = { number: Number(heading[1]), title: heading[2], items: [] };
    sections.push(current);
  } else if (line.startsWith('- [ ] ') && current) current.items.push(line.slice(6));
}
if (sections.length !== 18 || sections.some(s => !s.items.length)) throw new Error(`Unexpected checklist structure: ${sections.length} sections.`);

const esc = s => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
const run = (s, opts = {}) => `<w:r>${opts.bold ? '<w:rPr><w:b/></w:rPr>' : ''}<w:t xml:space="preserve">${esc(s)}</w:t></w:r>`;
const p = (s, style = 'Normal') => `<w:p><w:pPr><w:pStyle w:val="${style}"/></w:pPr>${run(s)}</w:p>`;
const cell = (s, width, opts = {}) => `<w:tc><w:tcPr><w:tcW w:w="${width}" w:type="dxa"/>${opts.shade ? `<w:shd w:fill="${opts.shade}"/>` : ''}</w:tcPr><w:p><w:pPr><w:spacing w:after="40"/></w:pPr>${opts.bold ? `<w:r><w:rPr><w:b/></w:rPr><w:t>${esc(s)}</w:t></w:r>` : run(s)}</w:p></w:tc>`;
const row = (values, widths, opts = {}) => `<w:tr>${values.map((v, i) => cell(v, widths[i], opts)).join('')}</w:tr>`;
const table = (rows, widths) => `<w:tbl><w:tblPr><w:tblW w:w="0" w:type="auto"/><w:tblBorders><w:top w:val="single" w:sz="4" w:color="B7C9D6"/><w:left w:val="single" w:sz="4" w:color="B7C9D6"/><w:bottom w:val="single" w:sz="4" w:color="B7C9D6"/><w:right w:val="single" w:sz="4" w:color="B7C9D6"/><w:insideH w:val="single" w:sz="4" w:color="D9E2E8"/><w:insideV w:val="single" w:sz="4" w:color="D9E2E8"/></w:tblBorders><w:tblLayout w:type="fixed"/></w:tblPr><w:tblGrid>${widths.map(w => `<w:gridCol w:w="${w}"/>`).join('')}</w:tblGrid>${rows.join('')}</w:tbl>`;

let body = p('IRON GRIND', 'Subtitle') + p('End-to-End Manual Test Checklist', 'Title') + p('Prepared as a test record. All checks start as Not tested; no results are claimed.', 'Subtitle');
for (const text of intro) body += p(text);
body += p('Test record', 'Heading1');
body += table([
  row(['Tester', '____________________________', 'Test date', '________________'], [1200, 3300, 1200, 2500]),
  row(['Build / URL', '____________________________', 'Environment', '________________'], [1200, 3300, 1200, 2500]),
], [1200, 3300, 1200, 2500]);
body += p('For each case, record the actual result, select Pass / Fail / Blocked / Not tested, and attach evidence when a problem occurs. Use test accounts and test records for payments and inventory changes.', 'Normal');
let seq = 0;
for (const section of sections) {
  body += p(`${section.number}. ${section.title}`, 'Heading1');
  const rows = [row(['Test ID', 'Test action / expected result', 'Actual result', 'Status', 'Evidence'], [1050, 4200, 1800, 1050, 1500], { bold: true, shade: 'DCEAF2' })];
  for (const [itemIndex, item] of section.items.entries()) {
    seq++;
    const prefix = section.number === 18 ? 'FLOW' : `S${String(section.number).padStart(2, '0')}`;
    rows.push(row([`${prefix}-${String(itemIndex + 1).padStart(2, '0')}`, item, '—', 'Not tested', '—'], [1050, 4200, 1800, 1050, 1500]));
  }
  body += table(rows, [1050, 4200, 1800, 1050, 1500]);
}
body += p(`Checklist count: ${seq} test cases across ${sections.length} sections.`, 'Heading1');
body += p('Completion summary', 'Heading2') + p('Passed: _____    Failed: _____    Blocked: _____    Not tested: _____');
body += p('Issues / follow-up notes', 'Heading2') + p('________________________________________________________________________________') + p('________________________________________________________________________________');

const documentXml = `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>${body}<w:sectPr><w:pgSz w:w="12240" w:h="15840"/><w:pgMar w:top="720" w:right="720" w:bottom="720" w:left="720"/></w:sectPr></w:body></w:document>`;
const stylesXml = `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:style w:type="paragraph" w:default="1" w:styleId="Normal"><w:name w:val="Normal"/><w:rPr><w:rFonts w:ascii="Aptos" w:hAnsi="Aptos"/><w:sz w:val="20"/></w:rPr><w:pPr><w:spacing w:after="100"/></w:pPr></w:style><w:style w:type="paragraph" w:styleId="Title"><w:name w:val="Title"/><w:rPr><w:b/><w:color w:val="123B56"/><w:sz w:val="34"/></w:rPr></w:style><w:style w:type="paragraph" w:styleId="Subtitle"><w:name w:val="Subtitle"/><w:rPr><w:color w:val="426579"/><w:sz w:val="22"/></w:rPr></w:style><w:style w:type="paragraph" w:styleId="Heading1"><w:name w:val="heading 1"/><w:basedOn w:val="Normal"/><w:next w:val="Normal"/><w:pPr><w:keepNext/><w:spacing w:before="240" w:after="100"/></w:pPr><w:rPr><w:b/><w:color w:val="123B56"/><w:sz w:val="26"/></w:rPr></w:style><w:style w:type="paragraph" w:styleId="Heading2"><w:name w:val="heading 2"/><w:basedOn w:val="Normal"/><w:rPr><w:b/><w:color w:val="123B56"/><w:sz w:val="22"/></w:rPr></w:style></w:styles>`;
const contentTypes = `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/><Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/></Types>`;
const rels = `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>`;
const docRels = `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/></Relationships>`;

function zip(entries) {
  const locals = [], centrals = [];
  let offset = 0;
  for (const [name, value] of Object.entries(entries)) {
    const n = Buffer.from(name), data = Buffer.from(value, 'utf8'), compressed = zlib.deflateRawSync(data), crc = crc32(data);
    const local = Buffer.alloc(30); local.writeUInt32LE(0x04034b50, 0); local.writeUInt16LE(20, 4); local.writeUInt16LE(0x800, 6); local.writeUInt16LE(8, 8); local.writeUInt32LE(crc, 14); local.writeUInt32LE(compressed.length, 18); local.writeUInt32LE(data.length, 22); local.writeUInt16LE(n.length, 26);
    locals.push(local, n, compressed);
    const central = Buffer.alloc(46); central.writeUInt32LE(0x02014b50, 0); central.writeUInt16LE(20, 4); central.writeUInt16LE(20, 6); central.writeUInt16LE(0x800, 8); central.writeUInt16LE(8, 10); central.writeUInt32LE(crc, 16); central.writeUInt32LE(compressed.length, 20); central.writeUInt32LE(data.length, 24); central.writeUInt16LE(n.length, 28); central.writeUInt32LE(offset, 42);
    centrals.push(central, n); offset += local.length + n.length + compressed.length;
  }
  const centralSize = centrals.reduce((n, b) => n + b.length, 0), end = Buffer.alloc(22); end.writeUInt32LE(0x06054b50, 0); end.writeUInt16LE(Object.keys(entries).length, 8); end.writeUInt16LE(Object.keys(entries).length, 10); end.writeUInt32LE(centralSize, 12); end.writeUInt32LE(offset, 16);
  return Buffer.concat([...locals, ...centrals, end]);
}
function crc32(buf) { let c = -1; for (const b of buf) { c ^= b; for (let k = 0; k < 8; k++) c = (c >>> 1) ^ (-(c & 1) & 0xedb88320); } return (c ^ -1) >>> 0; }

fs.mkdirSync(path.dirname(output), { recursive: true });
fs.writeFileSync(output, zip({ '[Content_Types].xml': contentTypes, '_rels/.rels': rels, 'word/document.xml': documentXml, 'word/styles.xml': stylesXml, 'word/_rels/document.xml.rels': docRels }));
console.log(`Created ${output} with ${seq} checklist cases in ${sections.length} sections.`);
