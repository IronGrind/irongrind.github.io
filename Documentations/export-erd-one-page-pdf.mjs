import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const directory = join(dirname(fileURLToPath(import.meta.url)), 'Chapter 3 Diagrams');
const stem = process.argv[2] || '05-erd-one-page';
const drawing = JSON.parse(readFileSync(join(directory, `${stem}-drawing.json`), 'utf8').replace(/^\uFEFF/, ''));
const expectedLinks = drawing.ExpectedLinks ?? 21;
const expectedTables = drawing.ExpectedTables ?? 16;
if (drawing.Primitives.filter(item => item.Kind === 'path').length !== expectedLinks) {
  throw new Error(`The drawing must contain ${expectedLinks} declared relationship paths.`);
}
const links = drawing.Primitives.filter(item => item.Kind === 'path');
const visible = links.flatMap((link, index) => (link.Segments || []).map(([a, b]) => ({ index, a, b, horizontal: a[1] === b[1] })));
for (let i = 0; i < visible.length; i++) {
  const a = visible[i];
  for (let j = i + 1; j < visible.length; j++) {
    const b = visible[j];
    if (a.index === b.index) continue;
    if (a.horizontal === b.horizontal) {
      const axis = a.horizontal ? 0 : 1, fixed = 1 - axis;
      const overlap = Math.min(Math.max(a.a[axis], a.b[axis]), Math.max(b.a[axis], b.b[axis])) - Math.max(Math.min(a.a[axis], a.b[axis]), Math.min(b.a[axis], b.b[axis]));
      if (Math.abs(a.a[fixed] - b.a[fixed]) < 0.001 && overlap > 0.001) throw new Error('Visible relationship segments overlap.');
    } else {
      const h = a.horizontal ? a : b, v = a.horizontal ? b : a;
      if (v.a[0] > Math.min(h.a[0], h.b[0]) && v.a[0] < Math.max(h.a[0], h.b[0]) && h.a[1] > Math.min(v.a[1], v.b[1]) && h.a[1] < Math.max(v.a[1], v.b[1])) throw new Error('A crossing has no separation gap.');
    }
  }
}
const cards = drawing.Primitives.filter(item => item.Kind === 'rect' && item.W === (drawing.TableWidth || 740) && item.H >= 132);
if (cards.length !== expectedTables) throw new Error(`Expected ${expectedTables} entity cards.`);
for (const line of visible) for (const card of cards) {
  const inside = line.horizontal
    ? line.a[1] > card.Y && line.a[1] < card.Y + card.H && Math.min(line.a[0], line.b[0]) < card.X + card.W && Math.max(line.a[0], line.b[0]) > card.X
    : line.a[0] > card.X && line.a[0] < card.X + card.W && Math.min(line.a[1], line.b[1]) < card.Y + card.H && Math.max(line.a[1], line.b[1]) > card.Y;
  if (inside) throw new Error('A relationship line passes through a table card.');
}
console.log(`Verified: ${expectedLinks} links, no shared visible segments or unmarked crossings, and no lines through table cards.`);
const pageWidth = (drawing.PageWidthMM || 297) * 72 / 25.4;
const pageHeight = (drawing.PageHeightMM || 210) * 72 / 25.4;
const scale = Math.min(pageWidth / drawing.Width, pageHeight / drawing.Height);
const offsetX = (pageWidth - drawing.Width * scale) / 2;
const offsetY = (pageHeight - drawing.Height * scale) / 2;
const n = value => Number(value).toFixed(4).replace(/\.?0+$/, '') || '0';
const color = hex => [1, 3, 5].map(i => n(parseInt(hex.slice(i, i + 2), 16) / 255)).join(' ');
const literal = value => String(value).replace(/([\\()])/g, '\\$1');
const operations = [`q ${n(scale)} 0 0 ${n(-scale)} ${n(offsetX)} ${n(pageHeight - offsetY)} cm`];
for (const item of drawing.Primitives) {
  if (item.Kind === 'rect') {
    operations.push(`${color(item.Fill)} rg ${color(item.Stroke)} RG ${n(item.LineWidth || 1.5)} w ${n(item.X)} ${n(item.Y)} ${n(item.W)} ${n(item.H)} re B`);
  } else if (item.Kind === 'text') {
    operations.push(`${color(item.Color)} rg BT /${item.Bold ? 'F2' : 'F1'} ${n(item.Size)} Tf 1 0 0 -1 ${n(item.X)} ${n(item.Y + item.Size)} Tm (${literal(item.Text)}) Tj ET`);
  } else if (item.Kind === 'path' || item.Kind === 'line') {
    const segments = item.Segments || item.Points.slice(1).map((point, i) => [item.Points[i], point]);
    operations.push(`${color(item.Color)} RG ${n(item.LineWidth || 3.2)} w ` + segments.map(([a, b]) => `${a.map(n).join(' ')} m ${b.map(n).join(' ')} l`).join(' ') + ' S');
  } else if (item.Kind === 'dot' || item.Kind === 'circle') {
    const x = item.X, y = item.Y, r = item.Radius || 4, k = r * 0.55228475;
    const paint = item.Kind === 'circle' ? `${color(item.Fill)} rg ${color(item.Stroke)} RG ${n(item.LineWidth || 2)} w` : `${color(item.Color)} rg`;
    operations.push(`${paint} ${n(x + r)} ${n(y)} m ` +
      `${n(x + r)} ${n(y + k)} ${n(x + k)} ${n(y + r)} ${n(x)} ${n(y + r)} c ` +
      `${n(x - k)} ${n(y + r)} ${n(x - r)} ${n(y + k)} ${n(x - r)} ${n(y)} c ` +
      `${n(x - r)} ${n(y - k)} ${n(x - k)} ${n(y - r)} ${n(x)} ${n(y - r)} c ` +
      `${n(x + k)} ${n(y - r)} ${n(x + r)} ${n(y - k)} ${n(x + r)} ${n(y)} c ${item.Kind === 'circle' ? 'B' : 'f'}`);
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
const target = join(directory, `${stem}.pdf`);
writeFileSync(target, pdf);
console.log(`Exported one vector PDF page (${drawing.PageWidthMM || 297} x ${drawing.PageHeightMM || 210} mm): ${target}`);
