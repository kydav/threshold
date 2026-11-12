// Snaps each field map onto its PDF's own fillable fields, the way the
// server does after reading an uploaded PDF (functions/lib/pdfFields.js),
// and reports how much closer the boxes get to the real fields.
//
// Writes OUT_DIR/<name>/map_snapped.json next to map.json. Costs nothing:
// no API calls.
//
// Usage: node snap.mjs OUT_DIR FORMS_DIR [MORE_FORMS_DIRS...]

import { readdirSync, readFileSync, writeFileSync, existsSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const require = createRequire(join(here, '../../functions/package.json'));
const { pdfWidgets, snapToPdfFields } = require('./lib/pdfFields.js');

const [outDir, ...formDirs] = process.argv.slice(2);
const pdfs = new Map();
for (const d of formDirs) {
  for (const f of readdirSync(d)) if (f.endsWith('.pdf')) pdfs.set(f.slice(0, -4), join(d, f));
}

const area = (b) => Math.max(0, b[2] - b[0]) * Math.max(0, b[3] - b[1]);
const inter = (a, b) =>
  area([Math.max(a[0], b[0]), Math.max(a[1], b[1]), Math.min(a[2], b[2]), Math.min(a[3], b[3])]);
const iou = (a, b) => {
  const i = inter(a, b);
  return i / (area(a) + area(b) - i || 1);
};

/** Mean IoU of each real field with the best mapped box on it. */
function fit(fields, truth) {
  if (!truth.length) return null;
  let sum = 0;
  for (const t of truth) {
    let best = 0;
    for (const f of fields) if (f.page === t.page) best = Math.max(best, iou(f.box, t.box));
    sum += best;
  }
  return sum / truth.length;
}

for (const name of readdirSync(outDir).sort()) {
  const dir = join(outDir, name);
  if (!existsSync(join(dir, 'map.json')) || !pdfs.has(name)) continue;
  const map = JSON.parse(readFileSync(join(dir, 'map.json'), 'utf8'));
  const sizes = JSON.parse(readFileSync(join(dir, 'pages.json'), 'utf8')).pages.map((p) => ({
    width: p.width,
    height: p.height,
  }));
  const widgets = await pdfWidgets(readFileSync(pdfs.get(name)), sizes);
  const count = widgets.reduce((s, p) => s + p.length, 0);
  const truth = existsSync(join(dir, 'truth.json'))
    ? JSON.parse(readFileSync(join(dir, 'truth.json'), 'utf8'))
    : [];
  const before = fit(map.fields, truth);
  const snapped = structuredClone(map);
  const moved = snapToPdfFields(snapped, widgets);
  writeFileSync(join(dir, 'map_snapped.json'), JSON.stringify(snapped, null, 1));
  const after = fit(snapped.fields, truth);
  const pct = (v) => (v == null ? '—' : `${(v * 100).toFixed(0)}%`);
  console.log(
    `${name.padEnd(46)} pdf fields ${String(count).padStart(3)}  moved ${String(moved).padStart(3)}/${map.fields.length}  overlap ${pct(before)} → ${pct(after)}`
  );
}
