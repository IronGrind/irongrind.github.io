import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const directory = join(dirname(fileURLToPath(import.meta.url)), 'Chapter 3 Diagrams');
const drawing = JSON.parse(readFileSync(join(directory, '05-erd-one-page-drawing.json'), 'utf8').replace(/^\uFEFF/, ''));
if (drawing.Primitives.filter(item => item.Kind === 'path').length !== 21) {
  throw new Error('The one-page drawing must contain all 21 declared foreign-key paths.');
}
const pageWidth = 297 * 72 / 25.4;
const pageHeight = 210 * 72 / 25.4;
const scale = Math.min(pageWidth / drawing.Width, pageHeight / drawing.Height);
const offsetX = (pageWidth - drawing.Width * scale) / 2;
const offsetY = (pageHeight - drawing.Height * scale) / 2;
const n = value => Number(value).toFixed(4).replace(/\.?0+$/, '') || '0';
const color = hex => [1, 3, 5].map(i => n(parseInt(hex.slice(i, i + 2), 16) / 255)).join(' ');
const literal = value => String(value).replace(/([\\()])/g, '\\$1');
const operations = [`q ${n(scale)} 0 0 ${n(-scale)} ${n(offsetX)} ${n(pageHeight - offsetY)} cm`];
for (const item of drawing.Primitives) {
  if (item.Kind === 'rect') {
    operations.push(`${color(item.Fill)} rg ${color(item.Stroke)} RG 1.5 w ${n(item.X)} ${n(item.Y)} ${n(item.W)} ${n(item.H)} re B`);
  } else if (item.Kind === 'text') {
    operations.push(`${color(item.Color)} rg BT /${item.Bold ? 'F2' : 'F1'} ${n(item.Size)} Tf 1 0 0 -1 ${n(item.X)} ${n(item.Y + item.Size)} Tm (${literal(item.Text)}) Tj ET`);
  } else if (item.Kind === 'path') {
    const segments = item.Segments || item.Points.slice(1).map((point, i) => [item.Points[i], point]);
    operations.push(`${color(item.Color)} RG 4 w ` + segments.map(([a, b]) => `${a.map(n).join(' ')} m ${b.map(n).join(' ')} l`).join(' ') + ' S');
  } else if (item.Kind === 'dot') {
    const x = item.X, y = item.Y, r = item.Radius || 4, k = r * 0.55228475;
    operations.push(`${color(item.Color)} rg ${n(x + r)} ${n(y)} m ` +
      `${n(x + r)} ${n(y + k)} ${n(x + k)} ${n(y + r)} ${n(x)} ${n(y + r)} c ` +
      `${n(x - k)} ${n(y + r)} ${n(x - r)} ${n(y + k)} ${n(x - r)} ${n(y)} c ` +
      `${n(x - r)} ${n(y - k)} ${n(x - k)} ${n(y - r)} ${n(x)} ${n(y - r)} c ` +
      `${n(x + k)} ${n(y - r)} ${n(x + r)} ${n(y - k)} ${n(x + r)} ${n(y)} c f`);
  } else {
    throw new Error(`Unrecognized drawing primitive: ${item.Kind}`);
  }
}
operations.push('Q');
const content = operations.join('\n') + '\n';
const objects = [
  '<< /Type /Catalog /Pages 2 0 R >>',
  '<< /Type /Pages /Count 1 /Kids [3 0 R] >>',
  `<< /Type /Page /Parent 2 0 R /MediaBox [0 0 ${n(pageWidth)} ${n(pageHeight)}] /Resources << /Font << /F1 5 0 R /F2 6 0 R >> >> /Contents 4 0 R >>`,
  `<< /Length ${Buffer.byteLength(content)} >>\nstream\n${content}endstream`,
  '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>',
  '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold /Encoding /WinAnsiEncoding >>'
];
let pdf = '%PDF-1.4\n';
const offsets = [0];
objects.forEach((object, index) => {
  offsets.push(Buffer.byteLength(pdf));
  pdf += `${index + 1} 0 obj\n${object}\nendobj\n`;
});
const xref = Buffer.byteLength(pdf);
pdf += `xref\n0 ${objects.length + 1}\n0000000000 65535 f \n`;
pdf += offsets.slice(1).map(offset => `${String(offset).padStart(10, '0')} 00000 n \n`).join('');
pdf += `trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n${xref}\n%%EOF\n`;
const target = join(directory, '05-erd-one-page.pdf');
writeFileSync(target, pdf);
console.log(`Exported one vector PDF page, A4 landscape (297 x 210 mm): ${target}`);
