import { readFileSync, writeFileSync } from 'node:fs';

const routes = JSON.parse(readFileSync(process.argv[2], 'utf8').replace(/^\uFEFF/, ''));
const lanes = routes.map(r => Object.fromEntries(r.Lanes.map(l => [l.Gutter, l.X])));
const buses = routes.map(r => r.Bus);
const groups = Object.values(Object.groupBy(routes, r => r.Group));
const choices = [0, 1, 2, 3].map(g => ({ kind: 'lane', gutter: g, members: routes.filter(r => r.Gutters.includes(g)).map(r => r.Index) }));
choices.push({ kind: 'bus', members: routes.filter(r => r.Bus > 0 && r.Bus < 200).map(r => r.Index) });
const mutable = choices.filter(c => c.members.length > 1);

function geometry() {
  const ys = [];
  for (const group of groups) {
    const base = group[0].BaseY;
    const up = group.filter(r => (r.Gutters.length > 1 ? buses[r.Index] : r.CY) < base);
    const down = group.filter(r => !up.includes(r));
    const distance = r => Math.abs(lanes[r.Index][r.Gutters[0]] - r.PX);
    up.sort((a, b) => distance(a) - distance(b));
    down.sort((a, b) => distance(b) - distance(a));
    up.forEach((r, i) => { ys[r.Index] = base - 19 + (i + 1) * 18 / (up.length + 1) + (r.Index + 1) * 0.013; });
    down.forEach((r, i) => { ys[r.Index] = base + (i + 1) * 18 / (down.length + 1) + (r.Index + 1) * 0.013; });
  }
  return routes.map(r => {
    const py = ys[r.Index], first = lanes[r.Index][r.Gutters[0]];
    const points = r.Gutters.length === 1
      ? [[r.PX, py], [first, py], [first, r.CY], [r.CX, r.CY]]
      : [[r.PX, py], [first, py], [first, buses[r.Index]], [lanes[r.Index][r.Gutters[1]], buses[r.Index]], [lanes[r.Index][r.Gutters[1]], r.CY], [r.CX, r.CY]];
    return { Index: r.Index, Points: points };
  });
}
function countCrossings(paths) {
  const hs = [], vs = [];
  paths.forEach(r => r.Points.slice(1).forEach((b, i) => {
    const a = r.Points[i];
    if (a[1] === b[1]) hs.push([r.Index, Math.min(a[0], b[0]), Math.max(a[0], b[0]), a[1]]);
    else vs.push([r.Index, a[0], Math.min(a[1], b[1]), Math.max(a[1], b[1])]);
  }));
  let count = 0;
  for (const h of hs) for (const v of vs) {
    if (h[0] !== v[0] && v[1] > h[1] && v[1] < h[2] && h[3] > v[2] && h[3] < v[3]) count++;
  }
  return count;
}
let seed = 18473;
function random() { seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0; return seed / 4294967296; }
const snapshot = () => ({ lanes: lanes.map(l => ({ ...l })), buses: [...buses] });
function restore(state) { state.lanes.forEach((l, i) => { lanes[i] = { ...l }; }); state.buses.forEach((b, i) => { buses[i] = b; }); }
let current = countCrossings(geometry()), best = current, bestState = snapshot();
const initial = current;
for (let step = 0; step < 24000; step++) {
  if (step > 0 && step % 6000 === 0) { restore(bestState); current = best; }
  const choice = mutable[Math.floor(random() * mutable.length)];
  const ai = Math.floor(random() * choice.members.length);
  let bi = Math.floor(random() * (choice.members.length - 1));
  if (bi >= ai) bi++;
  const a = choice.members[ai], b = choice.members[bi];
  const swap = () => {
    if (choice.kind === 'bus') [buses[a], buses[b]] = [buses[b], buses[a]];
    else [lanes[a][choice.gutter], lanes[b][choice.gutter]] = [lanes[b][choice.gutter], lanes[a][choice.gutter]];
  };
  swap();
  const candidate = countCrossings(geometry());
  const temperature = 2.5 * (1 - (step % 6000) / 6000) + 0.05;
  if (candidate <= current || random() < Math.exp((current - candidate) / temperature)) {
    current = candidate;
    if (current < best) { best = current; bestState = snapshot(); }
  } else swap();
}
restore(bestState);
writeFileSync(process.argv[3], JSON.stringify(geometry()));
console.log(`Reduced routing crossings from ${initial} to ${best}; every relationship retains a separate track.`);
