import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const dir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../Chapter 3 Diagrams');
const read = file => JSON.parse(fs.readFileSync(file, 'utf8').replace(/^\uFEFF/, ''));
const processes = read(path.join(dir, '03-gane-sarson-flows.json'));
const allowedPublicStoreIds = new Set(['D1','D2','D3','D4','D5','D6','D7','D8','D9','D10','D11']);
for (const process of processes) for (const store of process.Stores) if (!allowedPublicStoreIds.has(store[0])) throw new Error('Non-public DFD store: ' + store[0]);
const actorFlows = read(path.join(dir, ' _Sources/dfd-actor-flows.json'.trim()));

const reportStores = [
  ['D2', 'membership_applications', '', 'Application report records'],
  ['D3', 'members', '', 'Member report records'],
  ['D4', 'attendance', '', 'Attendance report records'],
  ['D5', 'products', '', 'Product report records'],
  ['D6', 'sales', '', 'Sales report records'],
  ['D7', 'sale_items', '', 'Sale-item report records'],
  ['D8', 'membership_history', '', 'Membership-history records'],
];
processes.find(process => process.Id === '8.0').Stores = reportStores;
// DFD store symbols intentionally cover public application tables only.

const actorLabels = [
  [
    ['Credentials / session request', 'Sign-in result / permitted role'],
    ['Credentials / session request', 'Administrator access result'],
    ['Credentials / session request', 'Staff access result'],
  ],
  [
    ['Registration details', 'Application status'],
    ['Review decision', 'Application / result'],
    ['Review decision', 'Limited request / result'],
  ],
  [
    ['Profile / staff controls', 'Profile / operation result'],
    ['Walk-in / renewal / plan change', 'Limited lookup / confirmation'],
    ['Own profile request / changes', 'Own profile details'],
  ],
  [
    ['Renewal request', 'Renewal status'],
    ['Renewal review decision', 'Request / result'],
    ['Renewal review decision', 'Limited request / result'],
  ],
  [
    ['QR / pairing / visit query', 'Visits / pairing / scan result'],
    ['QR / permitted visit query', 'Permitted visit / scan result'],
    ['Own attendance query', 'Own visit history'],
  ],
  [
    ['Product / stock changes', 'Catalog / stock / alerts'],
    ['Sales catalog query', 'Permitted catalog'],
    ['Active catalog query', 'Active products'],
  ],
  [
    ['Sale / transaction query', 'Transaction / result'],
    ['Sale details / own sales query', 'Sale result / own sales'],
  ],
  [['Report type / period', 'Report preview / export']],
  [['Activity filters / page', 'Filtered activity results']],
];

const shortStoreLabels = {
  D1: ['Profile / role records', 'Role / active status'],
  D2: ['Application / review data', 'Submitted applications'],
  D3: ['Member / membership data', 'Current member data'],
  D4: ['Visit / time records', 'Attendance history'],
  D5: ['Product / stock changes', 'Catalog / stock data'],
  D6: ['Transaction records', 'Permitted sales data'],
  D7: ['Sale-item records', 'Permitted line items'],
  D8: ['Membership changes', 'Membership history'],
  D9: ['Recorded operation event', 'Filtered activity records'],
  D10: ['Pairing-policy changes', 'Phone-pairing policy'],
  D11: ['Pairing-session changes', 'Paired phone sessions'],
};

const escape = value => String(value).replace(/[&<>"']/g, char => ({
  '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&apos;',
}[char]));
const wrap = (value, limit) => {
  const lines = [];
  let line = '';
  for (const word of String(value).split(/\s+/)) {
    const next = line ? `${line} ${word}` : word;
    if (next.length > limit && line) { lines.push(line); line = word; }
    else line = next;
  }
  if (line) lines.push(line);
  return lines;
};
const text = (x, y, value, size, color = '#172235', anchor = 'middle', limit = 35, weight = 400) => {
  const lines = wrap(value, limit);
  const offset = -((lines.length - 1) * size * 0.55);
  return `<text x="${x}" y="${y + offset}" text-anchor="${anchor}" font-family="Arial,sans-serif" font-size="${size}" font-weight="${weight}" fill="${color}">${lines.map((line, i) => `<tspan x="${x}" dy="${i ? size * 1.1 : 0}">${escape(line)}</tspan>`).join('')}</text>`;
};
const marker = '<defs><marker id="arrow" markerWidth="10" markerHeight="10" refX="9" refY="5" orient="auto"><path d="M0 0 L10 5 L0 10 Z" fill="#34445a"/></marker></defs>';

function makePanel(process, processIndex) {
  const actors = actorFlows[processIndex];
  const stores = process.Stores;
  const processHeight = Math.max(330, stores.length * 104 + 40, (actors.length - 1) * 145 + 150);
  const width = 2100;
  const top = 150;
  const height = top + processHeight + 85;
  const parts = [];
  parts.push(`<rect width="${width}" height="${height}" fill="#ffffff"/>`);
  parts.push(text(48, 52, `Process ${process.Id} â€” ${process.Name}`, 32, '#172235', 'start', 65, 700));
  parts.push(text(48, 94, 'Ganeâ€“Sarson notation Â· arrows show the direction of each data flow', 19, '#536274', 'start', 100));

  const actorX = 48, actorW = 285, processX = 700, processW = 440, storeX = 1605, storeW = 445;
  const actorH = 92, processY = top;
  const storeRow = 104, storeH = 78;
  const storeY = index => processY + 18 + index * storeRow;
  const actorCenter = index => processY + processHeight / 2 + (index - (actors.length - 1) / 2) * 145;

  parts.push(`<rect x="${processX}" y="${processY}" width="${processW}" height="${processHeight}" rx="16" fill="#e8f0fa" stroke="#244a78" stroke-width="3"/>`);
  parts.push(`<path d="M${processX} ${processY + 58} H${processX + processW}" stroke="#244a78" stroke-width="2"/>`);
  parts.push(text(processX + processW / 2, processY + 39, process.Id, 26, '#172235', 'middle', 12, 700));
  const titleLines = wrap(process.Name, 27);
  const titleStart = processY + processHeight / 2 - ((titleLines.length - 1) * 18);
  parts.push(`<text x="${processX + processW / 2}" y="${titleStart}" text-anchor="middle" font-family="Arial,sans-serif" font-size="29" font-weight="700" fill="#172235">${titleLines.map((line, i) => `<tspan x="${processX + processW / 2}" dy="${i ? 36 : 0}">${escape(line)}</tspan>`).join('')}</text>`);

  function flow(x1, x2, y, label, direction, maxChars) {
    const lines = wrap(label, maxChars);
    const labelH = Math.max(22, lines.length * 17 + 4);
    const labelW = Math.min(x2 - x1 - 18, Math.max(150, Math.max(...lines.map(line => line.length)) * 8.3 + 22));
    const labelX = (x1 + x2 - labelW) / 2;
    const labelY = y - labelH / 2;
    parts.push(`<path d="M${x1} ${y} H${x2}" fill="none" stroke="#34445a" stroke-width="2.2" marker-end="url(#arrow)"/>`);
    parts.push(`<rect x="${labelX}" y="${labelY}" width="${labelW}" height="${labelH}" rx="6" fill="#ffffff" stroke="#e1e6ed" stroke-width="1"/>`);
    parts.push(`<text x="${(x1 + x2) / 2}" y="${labelY + labelH / 2 + 5}" text-anchor="middle" font-family="Arial,sans-serif" font-size="15.5" fill="#26364a">${lines.map((line, i) => `<tspan x="${(x1 + x2) / 2}" dy="${i ? 17 : 0}">${escape(line)}</tspan>`).join('')}</text>`);
    return direction;
  }

  actors.forEach((actor, index) => {
    const center = actorCenter(index);
    const y = center - actorH / 2;
    parts.push(`<rect x="${actorX}" y="${y}" width="${actorW}" height="${actorH}" fill="#ffffff" stroke="#40516a" stroke-width="2.5"/>`);
    parts.push(text(actorX + actorW / 2, center + 8, actor[0], 22, '#172235', 'middle', 24, 700));
    const [inputLabel, outputLabel] = actorLabels[processIndex][index];
    flow(actorX + actorW, processX, center - 23, inputLabel, 'right', 35);
    flow(processX, actorX + actorW, center + 23, outputLabel, 'left', 35);
  });

  stores.forEach((store, index) => {
    const [id, name, writeData, readData] = store;
    const y = storeY(index);
    parts.push(`<path d="M${storeX + storeW} ${y} H${storeX} V${y + storeH} H${storeX + storeW} M${storeX + 83} ${y} V${y + storeH}" fill="#ffffff" stroke="#40516a" stroke-width="2.5"/>`);
    parts.push(text(storeX + 41, y + 46, id, 20, '#172235', 'middle', 9, 700));
    parts.push(text(storeX + 98, y + 42, name, 17, '#172235', 'start', 38, 500));
    const [writeLabel, readLabel] = shortStoreLabels[id] || [writeData || 'Updated records', readData || 'Stored records'];
    const writeY = y + 26;
    const readY = y + 60;
    if (writeData) flow(processX + processW, storeX, writeY, writeLabel, 'right', 33);
    if (readData) flow(storeX, processX + processW, readY, readLabel, 'left', 33);
  });

  parts.push(text(48, height - 24, 'Repeated actor and store names across panels identify the same system roles and physical data stores.', 17, '#536274', 'start', 105));
  const svg = `<?xml version="1.0" encoding="UTF-8"?>\n<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}" viewBox="0 0 ${width} ${height}" role="img" aria-labelledby="title desc">${marker}<title id="title">Process ${escape(process.Id)} â€” ${escape(process.Name)}</title><desc id="desc">Ganeâ€“Sarson DFD process with role-specific entities, individually labeled data stores, and separate directional flows.</desc>${parts.join('')}</svg>`;
  return { svg, width, height };
}

for (const [index, process] of processes.entries()) {
  const { svg } = makePanel(process, index);
  fs.writeFileSync(path.join(dir, `_Sources/dfd-process-${index + 1}.svg`), svg, 'utf8');
}
fs.writeFileSync(path.join(dir, '_Sources/dfd-process-panel-index.json'), JSON.stringify(processes.map((process, index) => ({
  panel: index + 1,
  processId: process.Id,
  name: process.Name,
  actors: actorFlows[index],
  stores: process.Stores,
  actorLabels: actorLabels[index],
  storeLabels: shortStoreLabels,
})), null, 2) + '\n');
console.log('Generated nine process-specific Ganeâ€“Sarson panels; each panel routes actor and store flows in separate lanes without crossing connectors.');
