import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const docsDir = path.resolve('Documentations');
const markdownPath = path.join(docsDir, 'IronGrind_Chapter_3_Revised.md');
const pdfPath = path.join(docsDir, 'CHAPTER-3irongrind.pdf');
const htmlPath = path.join(docsDir, 'CHAPTER-3irongrind-print.html');
const source = fs.readFileSync(markdownPath, 'utf8').split(/\r?\n/);

// Build the complete Chapter 3 source, including methodology, requirements,
// system design, data dictionary, forms, evaluation, scope, and schedule.
const lines = source;

function escapeHtml(value) {
  return value.replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);
}

function inline(value) {
  return escapeHtml(value)
    .replace(/`([^`]+)`/g, '<code>$1</code>')
    .replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>')
    .replace(/\*([^*]+)\*/g, '<em>$1</em>');
}

function isTableRow(line) { return /^\s*\|.*\|\s*$/.test(line); }
function tableCells(line) { return line.trim().slice(1, -1).split('|').map(cell => cell.trim()); }
function isTableDivider(line) { return isTableRow(line) && tableCells(line).every(cell => /^:?-{3,}:?$/.test(cell)); }

const output = [];
let index = 0;
while (index < lines.length) {
  const line = lines[index].trim();
  if (!line) { index++; continue; }

  const heading = /^(#{1,6})\s+(.*)$/.exec(line);
  if (heading) {
    const level = Math.min(heading[1].length, 4);
    output.push(`<h${level}>${inline(heading[2])}</h${level}>`);
    index++;
    continue;
  }

  const image = /^!\[([^\]]*)\]\(([^)]+)\)$/.exec(line);
  if (image) {
    const assetPath = path.resolve(docsDir, decodeURIComponent(image[2]));
    if (!fs.existsSync(assetPath)) throw new Error(`Missing diagram asset: ${assetPath}`);
    output.push(`<figure class="diagram"><img src="${pathToFileURL(assetPath).href}" alt="${escapeHtml(image[1])}"></figure>`);
    index++;
    continue;
  }

  if (isTableRow(line)) {
    const rows = [];
    while (index < lines.length && isTableRow(lines[index])) {
      if (!isTableDivider(lines[index])) rows.push(tableCells(lines[index]));
      index++;
    }
    const [header, ...body] = rows;
    output.push(`<div class="table-wrap"><table><thead><tr>${header.map(cell => `<th>${inline(cell)}</th>`).join('')}</tr></thead><tbody>${body.map(row => `<tr>${row.map(cell => `<td>${inline(cell)}</td>`).join('')}</tr>`).join('')}</tbody></table></div>`);
    continue;
  }

  if (/^-\s+/.test(line)) {
    const items = [];
    while (index < lines.length && /^\s*-\s+/.test(lines[index])) {
      items.push(`<li>${inline(lines[index].trim().replace(/^-\s+/, ''))}</li>`);
      index++;
    }
    output.push(`<ul>${items.join('')}</ul>`);
    continue;
  }

  const paragraph = [line];
  index++;
  while (index < lines.length && lines[index].trim()
    && !/^#{1,6}\s/.test(lines[index].trim())
    && !/^!\[/.test(lines[index].trim())
    && !isTableRow(lines[index].trim())
    && !/^\s*-\s+/.test(lines[index])) {
    paragraph.push(lines[index].trim());
    index++;
  }
  const content = paragraph.join(' ');
  output.push(/^\*\*Figure\s+\d+\./.test(content)
    ? `<p class="caption">${inline(content)}</p>`
    : `<p>${inline(content)}</p>`);
}

const html = `<!doctype html><html lang="en"><head><meta charset="utf-8"><title>IronGrind Chapter 3 — Research Methodology and System Design</title>
<style>
@page { size: Letter; margin: 0.9in 1in 0.9in 1.5in; @top-right { content: counter(page); font: 10pt "Times New Roman", serif; color: #20242c; } }
* { box-sizing: border-box; }
body { color: #20242c; font: 12pt/1.5 "Times New Roman", Times, serif; }
h1, h2, h3, h4 { color: #20242c; line-height: 1.2; page-break-after: avoid; font-family: "Times New Roman", Times, serif; }
h1 { margin: 0 0 5pt; text-align: center; font-size: 16pt; }
h1 + h1 { margin: 0 0 18pt; padding-bottom: 9pt; border-bottom: 0; font-size: 14pt; letter-spacing: .5pt; }
h2 { margin: 19pt 0 8pt; padding-bottom: 4pt; font-size: 14pt; text-transform: uppercase; }
h3 { margin: 14pt 0 6pt; font-size: 12pt; }
h4 { margin: 11pt 0 5pt; font-size: 12pt; }
p { margin: 0 0 8pt; text-align: justify; text-indent: 0.5in; orphans: 3; widows: 3; }
.caption, h1, h2, h3, h4, p:has(code) { text-indent: 0; }
ul { margin: 2pt 0 10pt; padding-left: 20pt; }
li { margin: 0 0 5pt; text-align: justify; }
code { font: 10pt Consolas, monospace; color: #283548; }
.table-wrap { margin: 6pt 0 13pt; }
table { width: 100%; border-collapse: collapse; font-size: 10pt; line-height: 1.2; }
th { background: #e9edf2; color: #20242c; font-weight: 700; text-align: left; }
th, td { border: 1px solid #aeb6c2; padding: 5pt 6pt; vertical-align: top; }
tr { page-break-inside: avoid; }
.diagram { margin: 7pt 0 0; text-align: center; page-break-inside: avoid; page-break-before: auto; }
.diagram img { display: block; width: auto; max-width: 100%; max-height: 8in; margin: 0 auto; object-fit: contain; }
.caption { margin: 2pt 0 10pt; text-align: center; font-size: 11pt; font-style: italic; }
strong { color: #20242c; }
</style></head><body>${output.join('\n')}</body></html>`;

fs.writeFileSync(htmlPath, html, 'utf8');
console.log(`Prepared ${htmlPath}`);
console.log(`Target PDF: ${pdfPath}`);
