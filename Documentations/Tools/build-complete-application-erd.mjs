import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const diagrams = join(dirname(fileURLToPath(import.meta.url)), '..', 'Chapter 3 Diagrams');
const archive = join(diagrams, '_Archive', 'Previous ERD Versions');
const model = JSON.parse(readFileSync(join(diagrams, 'schema-visualizer.json'), 'utf8').replace(/^\uFEFF/, ''));
const tables = model.Tables;
const relations = model.Relations;
const tableMap = new Map(tables.map(table => [table.Name, table]));
const fieldCount = tables.reduce((sum, table) => sum + table.Columns.length, 0);
if (tables.length !== 21 || fieldCount !== 224 || relations.length !== 33) throw new Error('Expected the verified 21-table, 224-field, 33-FK application schema.');

const esc = value => String(value).replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');
const privateOrder = [
  'private.account_sessions', 'private.admin_login_attempts', 'private.attendance_scan_requests',
  'private.admin_device_sessions', 'private.admin_login_approvals', 'private.admin_trusted_devices',
  'private.member_trusted_devices', 'private.member_device_sessions', 'private.member_device_approvals',
];
const extras = {
  'private.account_sessions': ['session_id'],
  'private.admin_login_attempts': ['window_start', 'attempts'],
  'private.attendance_scan_requests': ['created_at'],
  'private.admin_device_sessions': ['device_id', 'authorized_until'],
  'private.admin_login_approvals': ['status'],
  'private.admin_trusted_devices': ['device_id', 'device_label', 'expires_at'],
  'private.member_trusted_devices': ['device_id', 'device_label', 'last_seen_at'],
  'private.member_device_sessions': ['device_id', 'authorized_until'],
  'private.member_device_approvals': ['device_id', 'status'],
};
const shownFields = new Map();
for (const name of privateOrder) {
  const table = tableMap.get(name);
  if (!table) throw new Error(`Missing private table ${name}`);
  const selected = new Set([...table.Columns.filter(column => column.Keys.includes('PK') || column.Keys.includes('FK')).map(column => column.Name), ...(extras[name] || [])]);
  shownFields.set(name, table.Columns.filter(column => selected.has(column.Name)));
}
const privateRelations = relations.filter(relation => relation.Child.startsWith('private.'));
const expectedPrivateRelations = privateOrder.flatMap(name => relations.filter(relation => relation.Child === name));
if (privateRelations.length !== 15 || expectedPrivateRelations.some(relation => !shownFields.get(relation.Child).some(column => column.Name === relation.Field))) {
  throw new Error('Every private foreign-key field must appear in the simplified ERD.');
}

const leftWidth = 2300;
const width = 3600;
const height = 1800;
const panelX = 2385;
const cardX = 2410;
const cardW = 515;
const refX = 3070;
const refW = 450;
const rowTop = 155;
const rowStep = 178;
const headerH = 46;
const fieldH = 23;
const places = new Map();
const escText = (value, attrs) => `<text ${attrs}>${esc(value)}</text>`;
const svg = [`<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}" viewBox="0 0 ${width} ${height}">`, `<rect width="${width}" height="${height}" fill="white"/>`];
const oldSvg = readFileSync(join(archive, '05-gym-erd-public-only.svg'), 'utf8');
const match = oldSvg.match(/^<svg[^>]*>([\s\S]*)<\/svg>\s*$/);
if (!match) throw new Error('Could not read the preserved public ERD SVG.');
svg.push(match[1]);
svg.push(`<path d="M ${leftWidth + 24} 35 V ${height - 45}" stroke="#aab2bd" stroke-width="2"/>`);
svg.push(escText('Private application tables', `x="${panelX}" y="67" font-family="Arial" font-size="25" font-weight="700" fill="#172b46"`));
svg.push(escText('Key fields and short, local FK links; repeated target labels refer to existing tables.', `x="${panelX}" y="101" font-family="Arial" font-size="15" fill="#53647a"`));
svg.push('<defs><marker id="private-fk-arrow" markerWidth="8" markerHeight="8" refX="1" refY="4" orient="auto"><path d="M8 0L0 4L8 8Z" fill="#58687c"/></marker></defs>');

const tagRecords = [];
for (let index = 0; index < privateOrder.length; index++) {
  const name = privateOrder[index];
  const table = tableMap.get(name);
  const fields = shownFields.get(name);
  const y = rowTop + index * rowStep;
  const h = headerH + fields.length * fieldH;
  places.set(name, { x: cardX, y, w: cardW, h, fields });
  svg.push(`<rect x="${cardX}" y="${y}" width="${cardW}" height="${h}" fill="#fff" stroke="#344257" stroke-width="1.5"/>`);
  svg.push(`<rect x="${cardX}" y="${y}" width="${cardW}" height="${headerH}" fill="#ece8f7" stroke="#344257" stroke-width="1.5"/>`);
  svg.push(escText(name, `x="${cardX + 12}" y="${y + 29}" font-family="Arial" font-size="16" font-weight="700" fill="#172b46"`));
  for (let fieldIndex = 0; fieldIndex < fields.length; fieldIndex++) {
    const column = fields[fieldIndex];
    const fy = y + headerH + fieldIndex * fieldH;
    if (fieldIndex % 2 === 0) svg.push(`<rect x="${cardX + 1}" y="${fy}" width="${cardW - 2}" height="${fieldH}" fill="#f8fafc"/>`);
    const keys = column.Keys.join('/');
    svg.push(escText(keys, `x="${cardX + 11}" y="${fy + 16}" font-family="Arial" font-size="11.5" font-weight="700" fill="#315d96"`));
    svg.push(escText(column.Name, `x="${cardX + 76}" y="${fy + 16}" font-family="Arial" font-size="13.2" fill="#182433"`));
    svg.push(escText(column.Type, `x="${cardX + cardW - 10}" y="${fy + 16}" text-anchor="end" font-family="Arial" font-size="11.5" fill="#53647a"`));
    const rel = relations.find(item => item.Child === name && item.Field === column.Name);
    if (rel) tagRecords.push({ name, field: column.Name, target: `${rel.Parent}.${rel.ParentField}`, y: fy + fieldH / 2 });
  }
}

// Draw each private FK as a short parent-to-child link with an explicit target label.
for (const item of tagRecords) {
  const path = `M ${refX} ${item.y} H ${cardX + cardW + 18}`;
  svg.push(`<path class="private-fk" d="${path}" fill="none" stroke="#58687c" stroke-width="1.4" marker-end="url(#private-fk-arrow)"><title>${esc(`${item.target} references ${item.name}.${item.field}`)}</title></path>`);
  svg.push(`<rect x="${refX}" y="${item.y - 12}" width="${refW}" height="24" rx="4" fill="white" stroke="#b7c1ce" stroke-width="1"/>`);
  svg.push(escText(item.target, `x="${refX + 10}" y="${item.y + 4}" font-family="Arial" font-size="13" fill="#26364a"`));
}
svg.push(escText('21 unique application tables: 12 public + 9 private. The left panel retains the original public ERD layout. Private cards show PK/FK fields and selected identifiers; the data dictionary remains the source for all 224 fields.', `x="${panelX}" y="${height - 20}" font-family="Arial" font-size="14" fill="#53647a"`));
svg.push('</svg>');

// Extend the preserved public-only diagrams.net drawing so the main file stays editable.
let drawio = readFileSync(join(archive, '05-gym-erd-public-only.drawio'), 'utf8');
drawio = drawio.replace(/pageWidth="\d+"/g, `pageWidth="${width}"`).replace(/pageHeight="\d+"/g, `pageHeight="${height}"`).replace(/dx="\d+"/g, `dx="${width}"`).replace(/dy="\d+"/g, `dy="${height}"`);
const existingIds = new Set([...drawio.matchAll(/\bid="([^"]+)"/g)].map(item => item[1]));
let nextId = 1;
const id = () => { let candidate; do { candidate = `simple_${nextId++}`; } while (existingIds.has(candidate)); existingIds.add(candidate); return candidate; };
const cells = [];
const geom = (x, y, w, h) => `<mxGeometry x="${x}" y="${y}" width="${w}" height="${h}" as="geometry"/>`;
const plainCell = (value, style, x, y, w, h) => `<mxCell id="${id()}" value="${esc(value)}" style="${esc(style)}" vertex="1" parent="1">${geom(x, y, w, h)}</mxCell>`;
const privateTableIds = new Map();
const tagIds = [];
cells.push(plainCell('Private application tables', 'text;html=0;align=left;verticalAlign=middle;fontFamily=Arial;fontSize=24;fontStyle=1;fontColor=#172b46;', panelX, 42, 1000, 40));
cells.push(plainCell('Key fields and short, local FK links; repeated target labels refer to existing tables.', 'text;html=0;align=left;verticalAlign=middle;fontFamily=Arial;fontSize=14;fontColor=#53647a;', panelX, 76, 1100, 30));
for (const name of privateOrder) {
  const p = places.get(name);
  const fields = shownFields.get(name);
  const table = tableMap.get(name);
  const y = p.y;
  const text = [name, ...fields.map(column => `${column.Keys.join('/')}  ${column.Name} : ${column.Type}${column.Required ? ' *' : ''}`)].join('\n');
  const nodeId = id();
  privateTableIds.set(name, nodeId);
  cells.push(`<mxCell id="${nodeId}" value="${esc(text)}" style="rounded=0;whiteSpace=wrap;html=0;align=left;verticalAlign=top;spacing=10;fontFamily=Arial;fontSize=13;fillColor=#ffffff;strokeColor=#344257;" vertex="1" parent="1">${geom(cardX, y, cardW, p.h)}</mxCell>`);
}
for (const item of tagRecords) {
  const target = id();
  tagIds.push(target);
  cells.push(`<mxCell id="${target}" value="${esc(item.target)}" style="rounded=1;whiteSpace=wrap;html=0;align=left;verticalAlign=middle;spacing=6;fontFamily=Arial;fontSize=12;fillColor=#ffffff;strokeColor=#b7c1ce;" vertex="1" parent="1">${geom(refX, item.y - 12, refW, 24)}</mxCell>`);
  const edgeId = id();
  cells.push(`<mxCell id="${edgeId}" value="" style="edgeStyle=none;endArrow=block;endFill=1;strokeColor=#58687c;strokeWidth=1.2;" edge="1" parent="1"><mxGeometry relative="1" as="geometry"><mxPoint x="${refX}" y="${item.y}" as="sourcePoint"/><mxPoint x="${cardX + cardW + 18}" y="${item.y}" as="targetPoint"/></mxGeometry></mxCell>`);
}
const dividerId = id();
cells.push(`<mxCell id="${dividerId}" value="" style="strokeColor=#aab2bd;strokeWidth=1.5;" edge="1" parent="1"><mxGeometry relative="1" as="geometry"><mxPoint x="${leftWidth + 24}" y="35" as="sourcePoint"/><mxPoint x="${leftWidth + 24}" y="${height - 45}" as="targetPoint"/></mxGeometry></mxCell>`);
const insertion = drawio.lastIndexOf('</root>');
if (insertion < 0) throw new Error('Could not find diagrams.net root.');
drawio = drawio.slice(0, insertion) + cells.join('') + drawio.slice(insertion);

writeFileSync(join(diagrams, '05-gym-erd-editable.svg'), svg.join(''), 'utf8');
writeFileSync(join(diagrams, '05-gym-erd-editable.drawio'), drawio, 'utf8');
const preview = `<!doctype html><meta charset="utf-8"><style>html,body{margin:0;background:#e8edf3}img{display:block;width:1960px;height:auto;margin:20px auto;background:#fff;box-shadow:0 2px 12px #68778b55}</style><img src="../05-gym-erd-editable.svg" alt="Simplified complete application ERD">`;
writeFileSync(join(diagrams, '_Sources', '05-gym-erd-complete-preview.html'), preview, 'utf8');
console.log(`Generated simple ERD: 21 unique application tables, 33 declared FKs (18 public + ${tagRecords.length} private), and all ${fieldCount} schema fields retained in the data dictionary.`);
