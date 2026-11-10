import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const diagrams = join(dirname(fileURLToPath(import.meta.url)), '..', 'Chapter 3 Diagrams');
const model = JSON.parse(readFileSync(join(diagrams, 'schema-visualizer.json'), 'utf8').replace(/^\uFEFF/, ''));
const tables = model.Tables;
const relations = model.Relations;
const expectedFields = tables.reduce((sum, table) => sum + table.Columns.length, 0);
if (tables.length !== 21 || expectedFields !== 224 || relations.length !== 33) {
  throw new Error(`Schema inventory mismatch: ${tables.length} tables, ${expectedFields} fields, ${relations.length} FKs.`);
}

const esc = value => String(value).replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');
const byName = new Map(tables.map(table => [table.Name, table]));
const grid = [
  ['public.profiles', 'public.membership_applications', 'public.members'],
  ['public.attendance', 'public.membership_history', 'public.sales'],
  ['private.attendance_scan_requests', 'public.products', 'public.sale_items'],
  ['public.mobile_attendance_pairing_policy', 'public.mobile_attendance_scan_sessions', 'public.mobile_attendance_scan_events'],
  ['public.activity_logs', 'private.account_sessions', 'private.admin_login_attempts'],
  ['private.admin_login_approvals', 'private.admin_trusted_devices', 'private.admin_device_sessions'],
  ['private.member_trusted_devices', 'private.member_device_sessions', 'private.member_device_approvals'],
];
if (new Set(grid.flat()).size !== 21 || grid.flat().some(name => !byName.has(name))) throw new Error('Layout does not map each application table exactly once.');

const width = 5900;
const cardWidth = 1320;
const xs = [45, 1500, 2955];
const authX = 4410;
const headerH = 56;
const rowH = 23;
const rowGap = 54;
const top = 185;
const positions = new Map();
let y = top;
const rowYs = [];
for (const row of grid) {
  rowYs.push(y);
  const maxFields = Math.max(...row.map(name => byName.get(name).Columns.length));
  const height = headerH + maxFields * rowH;
  row.forEach((name, col) => positions.set(name, { x: xs[col], y, w: cardWidth, h: headerH + byName.get(name).Columns.length * rowH, col }));
  y += height + rowGap;
}
const height = y + 90;

const fieldIndex = (table, name) => {
  const index = table.Columns.findIndex(column => column.Name === name);
  if (index < 0) throw new Error(`Missing source column ${table.Name}.${name}`);
  return index;
};

const svg = [`<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}" viewBox="0 0 ${width} ${height}">`, '<rect width="100%" height="100%" fill="#fff"/>', '<style>text{font-family:Arial,sans-serif;fill:#182433}.relation{fill:none;stroke:#68778b;stroke-width:1.5;opacity:.72}.managed{stroke:#9aa4b2;stroke-dasharray:8 7}</style>',
  `<text x="45" y="48" font-size="34" font-weight="700">Iron Grind — Complete Application Database ERD</text>`,
  `<text x="45" y="88" font-size="20">21 application-owned tables · 224 fields · 33 declared foreign keys · supplied Supabase/pgAdmin schema and checked-in migrations through 20261110000006</text>`,
  `<text x="45" y="119" font-size="17">Public and private schemas are included. Supabase-managed auth tables appear only as reference nodes. FK labels mark the matching relationship fields; * means NOT NULL.</text>`];

const managed = {
  'auth.users': { x: authX, y: top + 20, w: 1320, h: 106, fields: ['id : uuid · PK'] },
  'auth.sessions': { x: authX, y: top + 160, w: 1320, h: 106, fields: ['id : uuid · PK'] },
};
for (const [name, node] of Object.entries(managed)) {
  svg.push(`<rect x="${node.x}" y="${node.y}" width="${node.w}" height="${node.h}" fill="#f5f7fa" stroke="#8d98a7" stroke-width="2"/>`);
  svg.push(`<rect x="${node.x}" y="${node.y}" width="${node.w}" height="38" fill="#e4e9ef" stroke="#8d98a7" stroke-width="2"/>`);
  svg.push(`<text x="${node.x + 18}" y="${node.y + 27}" font-size="19" font-weight="700">${name} (managed reference)</text>`);
  svg.push(`<text x="${node.x + 18}" y="${node.y + 75}" font-size="17">${node.fields[0]}</text>`);
}

// Draw declared FK links below the table cards; dashed lines terminate at managed Auth references.
for (const relation of relations) {
  const parentTable = byName.get(relation.Parent);
  const childTable = byName.get(relation.Child);
  const parent = positions.get(relation.Parent) || managed[relation.Parent];
  const child = positions.get(relation.Child);
  if (!parent || !child || !parentTable && !managed[relation.Parent]) throw new Error(`Unmapped relationship endpoint: ${relation.Parent} -> ${relation.Child}`);
  const childColumn = childTable.Columns[fieldIndex(childTable, relation.Field)];
  const sourceCol = parent.col ?? 3;
  const targetCol = child.col;
  const startRight = sourceCol <= targetCol;
  const p1 = { x: startRight ? parent.x + parent.w : parent.x, y: parent.y + (parentTable ? headerH + rowH / 2 : 75) };
  const p2 = { x: startRight ? child.x : child.x + child.w, y: child.y + headerH + fieldIndex(childTable, relation.Field) * rowH + rowH / 2 };
  let d;
  if (sourceCol === targetCol) {
    const lane = (startRight ? parent.x + parent.w + 18 : parent.x - 18) + (fieldIndex(childTable, relation.Field) % 5) * (startRight ? 5 : -5);
    d = `M ${p1.x} ${p1.y} C ${lane} ${p1.y}, ${lane} ${p2.y}, ${p2.x} ${p2.y}`;
  } else {
    const dir = p2.x >= p1.x ? 1 : -1;
    const bend = Math.max(90, Math.abs(p2.x - p1.x) * .38);
    d = `M ${p1.x} ${p1.y} C ${p1.x + dir * bend} ${p1.y}, ${p2.x - dir * bend} ${p2.y}, ${p2.x} ${p2.y}`;
  }
  const managedRef = relation.Parent.startsWith('auth.');
  svg.push(`<path class="relation${managedRef ? ' managed' : ''}" d="${d}"><title>${esc(`${relation.Parent}.${relation.ParentField} → ${relation.Child}.${relation.Field}; ON DELETE ${relation.Delete}`)}</title></path>`);
}

for (const row of grid) for (const name of row) {
  const table = byName.get(name);
  const p = positions.get(name);
  const isPrivate = name.startsWith('private.');
  const header = isPrivate ? '#ece8f7' : '#d5e2f5';
  svg.push(`<rect x="${p.x}" y="${p.y}" width="${p.w}" height="${p.h}" fill="#fff" stroke="#344257" stroke-width="2"/>`);
  svg.push(`<rect x="${p.x}" y="${p.y}" width="${p.w}" height="${headerH}" fill="${header}" stroke="#344257" stroke-width="2"/>`);
  svg.push(`<text x="${p.x + 18}" y="${p.y + 36}" font-size="21" font-weight="700">${esc(name)}</text>`);
  for (let i = 0; i < table.Columns.length; i++) {
    const col = table.Columns[i];
    const cy = p.y + headerH + i * rowH;
    if (i % 2 === 0) svg.push(`<rect x="${p.x + 1}" y="${cy}" width="${p.w - 2}" height="${rowH}" fill="#f8fafc"/>`);
    const keys = col.Keys.join('/');
    svg.push(`<text x="${p.x + 18}" y="${cy + 16}" font-size="14.5" font-weight="700" fill="#315d96">${esc(keys)}</text>`);
    svg.push(`<text x="${p.x + 125}" y="${cy + 16}" font-size="15.5">${esc(col.Name)}</text>`);
    svg.push(`<text x="${p.x + p.w - 16}" y="${cy + 16}" font-size="14.5" text-anchor="end" fill="#53647a">${esc(col.Type)}${col.Required ? ' *' : ''}</text>`);
  }
}
svg.push(`<text x="45" y="${height - 32}" font-size="16" fill="#53647a">PK primary key · FK foreign key · UQ unique · * NOT NULL. Lines show declared foreign keys only; device identifiers without constraints are not linked.</text>`, '</svg>');

// Create a diagrams.net source with editable table groups and relationship edges.
const cells = ['<mxCell id="0"/>', '<mxCell id="1" parent="0"/>'];
let serial = 1;
const cell = (value, style, geometry, parent = '1', extra = '') => {
  const id = `c${serial++}`;
  cells.push(`<mxCell id="${id}" value="${esc(value)}" style="${esc(style)}" parent="${parent}" ${extra}>${geometry}</mxCell>`);
  return id;
};
const geo = (x, y, w, h, relative = false) => `<mxGeometry x="${x}" y="${y}" width="${w}" height="${h}"${relative ? ' relative="1"' : ''} as="geometry"/>`;
const groupIds = new Map();
cell('Iron Grind — Complete Application Database ERD\n21 tables · 224 fields · 33 declared FKs · * = NOT NULL', 'text;html=0;align=left;whiteSpace=wrap;fontFamily=Arial;fontSize=24;fontStyle=1;', geo(45, 25, 5700, 105));
for (const row of grid) for (const name of row) {
  const table = byName.get(name), p = positions.get(name), isPrivate = name.startsWith('private.');
  const group = cell('', 'group;', geo(p.x, p.y, p.w, p.h), '1', 'vertex="1" connectable="0"');
  groupIds.set(name, group);
  cell('', `rounded=0;fillColor=${isPrivate ? '#ece8f7' : '#d5e2f5'};strokeColor=#344257;strokeWidth=1;`, geo(0, 0, p.w, headerH), group, 'vertex="1"');
  cell(name, 'text;html=0;align=left;verticalAlign=middle;fontFamily=Arial;fontSize=18;fontStyle=1;', geo(18, 10, p.w - 36, 34), group, 'vertex="1"');
  for (let i = 0; i < table.Columns.length; i++) {
    const col = table.Columns[i], ky = col.Keys.length ? `${col.Keys.join('/')}  ` : '';
    const val = `${ky}${col.Name} : ${col.Type}${col.Required ? ' *' : ''}`;
    cell(val, `text;html=0;align=left;verticalAlign=middle;whiteSpace=wrap;fontFamily=Arial;fontSize=13;fontColor=${col.Keys.length ? '#315d96' : '#182433'};`, geo(16, headerH + i * rowH, p.w - 32, rowH), group, 'vertex="1"');
  }
}
for (const [name, p] of Object.entries(managed)) {
  const group = cell('', 'group;', geo(p.x, p.y, p.w, p.h), '1', 'vertex="1" connectable="0"');
  groupIds.set(name, group);
  cell('auth managed reference', 'text;html=0;align=left;verticalAlign=middle;fontFamily=Arial;fontSize=14;fontStyle=1;', geo(18, 5, p.w - 36, 32), group, 'vertex="1"');
  cell(`${name}\nid : uuid (PK)`, 'text;html=0;align=left;verticalAlign=middle;fontFamily=Arial;fontSize=16;', geo(18, 44, p.w - 36, 54), group, 'vertex="1"');
}
for (const relation of relations) {
  const managedRef = relation.Parent.startsWith('auth.');
  cell('', `edgeStyle=orthogonalEdgeStyle;rounded=1;curved=1;strokeColor=${managedRef ? '#9aa4b2' : '#68778b'};strokeWidth=1.4;dashed=${managedRef ? 1 : 0};dashPattern=8 7;`, `<mxGeometry relative="1" as="geometry"/>`, '1', `edge="1" source="${groupIds.get(relation.Parent)}" target="${groupIds.get(relation.Child)}"`);
}
const drawio = `<?xml version="1.0" encoding="UTF-8"?><mxfile host="app.diagrams.net"><diagram id="complete-app-erd" name="Complete Application ERD"><mxGraphModel dx="${width}" dy="${height}" grid="1" gridSize="10" guides="1" tooltips="1" connect="1" arrows="1" page="1" pageScale="1" pageWidth="${width}" pageHeight="${height}"><root>${cells.join('')}</root></mxGraphModel></diagram></mxfile>`;

writeFileSync(join(diagrams, '05-gym-erd-editable.svg'), svg.join(''), 'utf8');
writeFileSync(join(diagrams, '05-gym-erd-editable.drawio'), drawio, 'utf8');
const preview = `<!doctype html><meta charset="utf-8"><style>html,body{margin:0;background:#e8edf3}img{display:block;width:1960px;height:auto;margin:20px auto;background:#fff;box-shadow:0 2px 12px #68778b55}</style><img src="../05-gym-erd-editable.svg" alt="Complete application database ERD">`;
writeFileSync(join(diagrams, '_Sources', '05-gym-erd-complete-preview.html'), preview, 'utf8');
console.log(`Generated complete ERD: ${tables.length} application tables, ${expectedFields} fields, ${relations.length} declared foreign keys; two managed reference nodes.`);
