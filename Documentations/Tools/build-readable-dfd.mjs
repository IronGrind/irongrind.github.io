import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../Chapter 3 Diagrams');
const readJson = file => JSON.parse(fs.readFileSync(file, 'utf8').replace(/^\uFEFF/, ''));
const processes = readJson(path.join(root, '03-gane-sarson-flows.json'));
const actorFlows = readJson(path.join(root, '_Sources/dfd-actor-flows.json'));

// Do not group report stores into a range; each store gets its own symbol and flow.
const reportStores = [
  ['D2', 'membership_applications', '', 'Application report records'],
  ['D3', 'members', '', 'Member report records'],
  ['D4', 'attendance', '', 'Attendance report records'],
  ['D5', 'products', '', 'Product report records'],
  ['D6', 'sales', '', 'Sales report records'],
  ['D7', 'sale_items', '', 'Sale item report records'],
  ['D8', 'membership_history', '', 'Membership history records']
];
processes.find(process => process.Id === '8.0').Stores = reportStores;
// Resolve stores to exact tables in the documented database baseline.
const schema = readJson(path.join(root, 'schema-visualizer.json'));
const tableNames = new Set(schema.Tables.map(table => table.Name));
tableNames.add('auth.users');
const storeTables = {
 D0:'auth.users', D1:'public.profiles', D2:'public.membership_applications',
 D3:'public.members', D4:'public.attendance', D5:'public.products',
 D6:'public.sales', D7:'public.sale_items', D8:'public.membership_history',
 D9:'public.activity_logs', D10:'public.mobile_attendance_pairing_policy',
 D11:'public.mobile_attendance_scan_sessions', D13:'private.attendance_scan_requests',
 D14:'private.account_sessions', D15:'private.admin_login_approvals',
 D16:'private.admin_trusted_devices', D17:'private.admin_device_sessions'
};
for (const process of processes) {
 const seen = new Set();
 process.Stores = process.Stores.filter(store => {
  if (seen.has(store[0])) return false;
  seen.add(store[0]); return true;
 }).map(store => {
  const name = storeTables[store[0]];
  if (!tableNames.has(name)) throw new Error('Unverified DFD table: ' + store[0]);
  return [store[0], name.split('.').at(-1), store[2], store[3]];
 });
}

const esc = value => String(value).replace(/[&<>"']/g, char => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&apos;' })[char]);
const wrap = (value, max = 32) => {
  const words = String(value).split(/\s+/);
  const lines = [];
  let line = '';
  for (const word of words) {
    const next = line ? `${line} ${word}` : word;
    if (next.length > max && line) { lines.push(line); line = word; }
    else line = next;
  }
  if (line) lines.push(line);
  return lines;
};
const text = (x, y, value, className, anchor = 'middle', max = 32) => {
  const lines = wrap(value, max);
  const first = y - ((lines.length - 1) * 9);
  return `<text x="${x}" y="${first}" class="${className}" text-anchor="${anchor}">${lines.map((line, i) => `<tspan x="${x}" dy="${i ? 18 : 0}">${esc(line)}</tspan>`).join('')}</text>`;
};
const box = (x, y, w, h, radius = 0, cls = 'entity') => `<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="${radius}" class="${cls}"/>`;
const dataStore = (x, y, w, h, id, name) => `<path d="M${x} ${y}h${w} M${x} ${y}v${h} M${x} ${y + h}h${w} M${x + 70} ${y}v${h}" class="store"/>${text(x + 35, y + h / 2 + 6, id, 'store-id')}${text(x + 92, y + h / 2 + 6, name, 'store-name', 'start', 48)}`;
const arrow = (x1, y, x2, label, direction = 'right') => {
  if (direction === 'left' && x1 < x2) [x1, x2] = [x2, x1];
  // Keep the endpoint at the flow destination so every arrowhead points into
  // the receiving actor/process/store, regardless of flow direction.
  const mid = (x1 + x2) / 2;
  const labelWidth = Math.min(480, Math.max(210, label.length * 9));
  return `<path d="M${x1} ${y}H${x2}" class="flow" marker-end="url(#arrow-end)"/><rect x="${mid - labelWidth / 2}" y="${y - 20}" width="${labelWidth}" height="17" rx="7" class="label-bg"/>${text(mid, y - 7, label, 'flow-label', 'middle', 62)}`;
};

let cursorY = 320;
const panels = [];
const panelGap = 44;
const actorX = 80, actorW = 390, processX = 1210, processW = 500, storeX = 2460, storeW = 870;
const actorFlowEnd = processX;
const processStoreStart = processX + processW;
const storeFlowEnd = storeX;
for (let i = 0; i < processes.length; i++) {
  const process = processes[i];
  const actors = actorFlows[i] || [];
  const actorBlock = 80 + actors.length * 142;
  const storeBlock = 82 + process.Stores.length * 116;
  const height = Math.max(420, actorBlock, storeBlock) + 40;
  let body = `<g id="process-${i + 1}" transform="translate(0 ${cursorY})">`;
  body += `<rect x="45" y="0" width="3260" height="${height}" rx="22" class="panel"/>`;
  body += `<text x="80" y="40" class="panel-title">${esc(process.Id)} · ${esc(process.Name)}</text>`;

  actors.forEach((actor, index) => {
    const y = 76 + index * 142;
    body += box(actorX, y, actorW, 104, 12, 'entity');
    body += text(actorX + actorW / 2, y + 31, actor[0], 'entity-title', 'middle', 34);
    body += arrow(actorX + actorW, y + 53, actorFlowEnd, actor[1]);
    body += arrow(actorX + actorW, y + 91, actorFlowEnd, actor[2], 'left');
  });

  const processY = 60;
  const processH = height - 120;
  body += box(processX, processY, processW, processH, 18, 'process');
  body += `<path d="M${processX} ${processY + 48}H${processX + processW}" class="process-separator"/>`;
  body += text(processX + processW / 2, processY + 33, process.Id, 'process-number');
  const nameLines = wrap(process.Name, 28);
  const nameStart = processY + processH / 2 - ((nameLines.length - 1) * 16);
  body += `<text x="${processX + processW / 2}" y="${nameStart}" class="process-name" text-anchor="middle">${nameLines.map((line, j) => `<tspan x="${processX + processW / 2}" dy="${j ? 32 : 0}">${esc(line)}</tspan>`).join('')}</text>`;
  process.Stores.forEach((store, index) => {
    const y = 68 + index * 116;
    const storeH = 76;
    body += dataStore(storeX, y, storeW, storeH, store[0], store[1]);
    if (store[2]) body += arrow(processStoreStart, y + 26, storeFlowEnd, store[2]);
    if (store[3]) body += arrow(storeFlowEnd, y + 56, processStoreStart, store[3], 'left');
  });
  body += `</g>`;
  panels.push(body);
  cursorY += height + panelGap;
}

const width = 3360;
const height = cursorY + 190;
const header = `<g><text x="80" y="82" class="title">Iron Grind Fitness Gym — Complete Level 1 DFD</text>
<text x="80" y="122" class="subtitle">Gane–Sarson notation · nine processes · named actors and individual data stores</text>
<g transform="translate(80 160)">${box(0, 0, 280, 58, 0, 'entity')}<text x="140" y="36" class="legend">External entity</text>
${box(350, 0, 300, 58, 14, 'process')}<text x="500" y="36" class="legend">Process</text>
<path d="M740 0h310 M740 0v58 M740 58h310 M810 0v58" class="store"/><text x="900" y="36" class="legend">Data store</text>
<path d="M1140 30h310" class="flow" marker-end="url(#arrow-end)"/><text x="1295" y="18" class="legend">Data flow</text></g>
<text x="80" y="250" class="note">Each data store uses its database table name. Repeated D identifiers refer to the same table; no placeholder stores are included.</text>
<text x="80" y="276" class="note">Table names match the documented pgAdmin baseline and migrations through 20261110000004; this is not fresh live-schema introspection.</text></g>`;
const style = `<style>
 text{font-family:Arial,sans-serif;fill:#172235}.title{font-size:38px;font-weight:700}.subtitle{font-size:22px;fill:#536274}.panel-title{font-size:25px;font-weight:700}.note{font-size:17px;fill:#536274}.legend{font-size:18px;font-weight:600;text-anchor:middle}.panel{fill:#fff;stroke:#d1d9e3;stroke-width:2}.entity{fill:#fff;stroke:#40516a;stroke-width:2.5}.entity-title{font-size:20px;font-weight:700}.process{fill:#e1ebf8;stroke:#244a78;stroke-width:3}.process-separator{stroke:#244a78;stroke-width:2}.process-number{font-size:21px;font-weight:700}.process-name{font-size:26px;font-weight:700}.store{fill:none;stroke:#40516a;stroke-width:2.5}.store-id{font-size:18px;font-weight:700}.store-name{font-size:17px}.flow{fill:none;stroke:#34445a;stroke-width:2}.flow-label{font-size:14px;fill:#26364a}.label-bg{fill:#fff;stroke:#e1e6ed;stroke-width:1}.page{fill:#f6f8fb}
</style>`;
const svg = `<?xml version="1.0" encoding="UTF-8"?>\n<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}" viewBox="0 0 ${width} ${height}" role="img" aria-labelledby="title desc"><title id="title">Iron Grind Fitness Gym — Complete Level 1 DFD</title><desc id="desc">Nine process panels in Gane–Sarson notation, with external entities, separately identified data stores, and labeled data flows.</desc><defs><marker id="arrow-end" markerWidth="9" markerHeight="9" refX="8" refY="4.5" orient="auto"><path d="M0 0L9 4.5L0 9Z" fill="#34445a"/></marker></defs>${style}<rect class="page" width="100%" height="100%"/>${header}${panels.join('')}<text x="80" y="${height - 42}" class="note">Source: Chapter 3 Level 1 process/actor-flow model and User Login security-store supplement. Standalone complete Level 1 DFD. The Word chapter presents the same model in five panels (Figures 3a-e); Figure 3f isolates the administrator security stores.</text></svg>`;
fs.writeFileSync(path.join(root, '03-dfd-complete-gane-sarson.svg'), svg, 'utf8');
