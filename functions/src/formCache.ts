import { createHash } from 'crypto';
import type { Firestore } from 'firebase-admin/firestore';
import type { FieldMap, OcrWord, PageInput } from './mapFields';

/**
 * Reuses a form another agent already imported and confirmed.
 *
 * Nothing of the form itself is stored: each page keeps only hashes of its
 * longer printed lines, with their positions, and the field map
 * (labels, kinds and boxes). A new upload whose printed lines match a
 * confirmed form gets that form's fields, moved onto its own pages using
 * the matching lines as anchors (a scan is never framed exactly like the
 * original).
 */

/** Printed lines shorter than this are too generic to identify a form. */
const MIN_LINE = 12;
/** A page matches when this share of the smaller side's lines match... */
const MIN_COVERAGE = 0.6;
/** ...and at least this many lines. */
const MIN_MATCHED = 5;
/** Anchor fit error allowed, as a share of the page size. */
const MAX_RMS = 0.012;
/** Page-1 hashes kept on each cached form for lookups. */
const KEY_COUNT = 120;
/**
 * Different agents who must have imported and reviewed the same form
 * before it's offered to everyone else, so one agent's bad review
 * doesn't spread.
 */
export const MIN_AGENTS = 3;

export interface Anchor {
  h: string;
  box: number[];
}

export interface AnchorPage {
  width: number;
  height: number;
  anchors: Anchor[];
}

export interface Fit {
  sx: number;
  tx: number;
  sy: number;
  ty: number;
}

const normalize = (t: string) =>
  t
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, ' ')
    .trim();

/** A printed line as a hash, so the cache holds no readable form text. */
const hash = (t: string) =>
  createHash('sha256')
    .update(`threshold-form-line:${normalize(t)}`)
    .digest('hex')
    .slice(0, 24);

/** Whether most of [inner] lies inside [outer]. Both [x0, y0, x1, y1]. */
function mostlyInside(outer: number[], inner: number[]): boolean {
  const w = Math.min(outer[2], inner[2]) - Math.max(outer[0], inner[0]);
  const h = Math.min(outer[3], inner[3]) - Math.max(outer[1], inner[1]);
  if (w <= 0 || h <= 0) return false;
  const area = (inner[2] - inner[0]) * (inner[3] - inner[1]);
  return area > 0 && (w * h) / area > 0.3;
}

/**
 * A page's anchors: its longer printed lines, hashed, longest first. Lines
 * inside any [exclude] box (a field's answer on a filled copy) are left
 * out, and so is a line printed twice on the page (its position is
 * ambiguous).
 */
export function anchorsFor(ocr: OcrWord[], exclude: number[][] = []): Anchor[] {
  const seen = new Map<string, { a: Anchor; len: number } | null>();
  for (const line of ocr) {
    const len = normalize(line.text ?? '').length;
    if (len < MIN_LINE || !Array.isArray(line.box) || line.box.length !== 4) {
      continue;
    }
    if (exclude.some((b) => mostlyInside(b, line.box))) continue;
    const h = hash(line.text);
    seen.set(h, seen.has(h) ? null : { a: { h, box: line.box }, len });
  }
  return [...seen.values()]
    .filter((v): v is { a: Anchor; len: number } => v !== null)
    .sort((x, y) => y.len - x.len)
    .map((v) => v.a);
}

/** Least-squares dst = s * src + t; returns s, t and the RMS error. */
function fit1d(src: number[], dst: number[]) {
  const n = src.length;
  const ms = src.reduce((a, b) => a + b, 0) / n;
  const md = dst.reduce((a, b) => a + b, 0) / n;
  let cov = 0;
  let varS = 0;
  for (let i = 0; i < n; i++) {
    cov += (src[i] - ms) * (dst[i] - md);
    varS += (src[i] - ms) ** 2;
  }
  const s = varS > 0 ? cov / varS : 1;
  const t = md - s * ms;
  const err = src.map((x, i) => s * x + t - dst[i]);
  const rms = Math.sqrt(err.reduce((a, e) => a + e * e, 0) / n);
  return { s, t, rms, err };
}

/**
 * How [cached]'s page maps onto [upload]'s, from the lines both share, or
 * null when they don't share enough or the positions don't line up.
 */
export function fitPage(
  cached: AnchorPage,
  upload: AnchorPage
): { fit: Fit; coverage: number } | null {
  const target = new Map(upload.anchors.map((a) => [a.h, a.box]));
  let pairs = cached.anchors
    .filter((a) => target.has(a.h))
    .map((a) => ({ from: a.box, to: target.get(a.h)! }));
  const smaller = Math.min(cached.anchors.length, upload.anchors.length);
  const coverage = smaller ? pairs.length / smaller : 0;
  if (pairs.length < MIN_MATCHED || coverage < MIN_COVERAGE) return null;

  const solve = () => ({
    x: fit1d(
      pairs.flatMap((p) => [p.from[0], p.from[2]]),
      pairs.flatMap((p) => [p.to[0], p.to[2]])
    ),
    y: fit1d(
      pairs.flatMap((p) => [p.from[1], p.from[3]]),
      pairs.flatMap((p) => [p.to[1], p.to[3]])
    ),
  });
  let { x, y } = solve();
  // OCR now and then splits or trims a line differently: drop the worst
  // fifth of the pairs and fit again.
  if (pairs.length >= 10) {
    const worst = pairs
      .map((p, i) => ({
        p,
        e: Math.hypot(x.err[2 * i], x.err[2 * i + 1], y.err[2 * i], y.err[2 * i + 1]),
      }))
      .sort((a, b) => a.e - b.e);
    pairs = worst.slice(0, Math.ceil(worst.length * 0.8)).map((w) => w.p);
    ({ x, y } = solve());
  }
  const ok =
    x.rms / upload.width <= MAX_RMS &&
    y.rms / upload.height <= MAX_RMS &&
    x.s > 0.3 &&
    x.s < 3 &&
    y.s > 0.3 &&
    y.s < 3;
  return ok ? { fit: { sx: x.s, tx: x.t, sy: y.s, ty: y.t }, coverage } : null;
}

/** [box] moved by [fit], kept on a [width] x [height] page. */
export function moveBox(box: number[], fit: Fit, width: number, height: number) {
  const cx = (v: number) => Math.round(Math.min(width, Math.max(0, v)));
  const cy = (v: number) => Math.round(Math.min(height, Math.max(0, v)));
  return [
    cx(fit.sx * box[0] + fit.tx),
    cy(fit.sy * box[1] + fit.ty),
    cx(fit.sx * box[2] + fit.tx),
    cy(fit.sy * box[3] + fit.ty),
  ];
}

/** Each page's size and anchors, leaving out the map's field boxes. */
export function anchorPages(pages: PageInput[], map?: FieldMap): AnchorPage[] {
  return pages.map((p, i) => {
    const boxes = (map?.fields ?? [])
      .filter((f) => f.page === i + 1 && Array.isArray(f.box))
      .map((f) => f.box as number[]);
    return { width: p.width, height: p.height, anchors: anchorsFor(p.ocr, boxes) };
  });
}

interface CachedForm {
  ownerUid: string;
  confirmed: boolean;
  pageCount: number;
  keys: string[];
  pages: AnchorPage[];
  map: FieldMap;
}

/**
 * A reviewed form whose pages match [pages], with its fields moved onto
 * them; null when none matches or fewer than [MIN_AGENTS] different agents
 * have reviewed a matching copy. Fields come back with currently_filled
 * false: the app checks each box for ink on this copy itself.
 */
export async function findCached(
  db: Firestore,
  pages: PageInput[]
): Promise<{ map: FieldMap; sourceId: string } | null> {
  const upload = anchorPages(pages);
  const keys = upload[0].anchors.slice(0, 30).map((a) => a.h);
  if (keys.length < MIN_MATCHED) return null;

  const snap = await db
    .collection('formMaps')
    .where('keys', 'array-contains-any', keys)
    .limit(100)
    .get();

  let best: { id: string; form: CachedForm; fits: Fit[]; score: number } | null =
    null;
  const agents = new Set<string>();
  for (const doc of snap.docs) {
    const form = doc.data() as CachedForm;
    if (!form.confirmed || form.pageCount !== pages.length) continue;
    const fits: Fit[] = [];
    let score = 0;
    for (let i = 0; i < pages.length; i++) {
      const r = fitPage(form.pages[i], upload[i]);
      if (!r) break;
      fits.push(r.fit);
      score += r.coverage;
    }
    if (fits.length !== pages.length) continue;
    agents.add(form.ownerUid);
    if (!best || score > best.score) best = { id: doc.id, form, fits, score };
  }
  if (!best || agents.size < MIN_AGENTS) return null;

  const { form, fits } = best;
  const map: FieldMap = {
    ...form.map,
    fields: form.map.fields.map((f) => {
      const page = (f.page as number) - 1;
      const p = pages[page];
      return {
        ...f,
        box: p ? moveBox(f.box as number[], fits[page], p.width, p.height) : f.box,
        currently_filled: false,
      };
    }),
  };
  return { map, sourceId: best.id };
}

/**
 * Keeps a freshly read form as a cache candidate (formMaps/[jobId]). It
 * counts toward the cache once its agent reviews and saves it
 * ([confirmCached]), and is offered to others once [MIN_AGENTS] different
 * agents have reviewed the same form.
 */
export async function saveCandidate(
  db: Firestore,
  jobId: string,
  uid: string,
  pages: PageInput[],
  map: FieldMap
): Promise<void> {
  const anchored = anchorPages(pages, map);
  if (anchored[0].anchors.length < MIN_MATCHED) return;
  const form: CachedForm & { createdAt: Date } = {
    ownerUid: uid,
    confirmed: false,
    pageCount: pages.length,
    keys: anchored[0].anchors.slice(0, KEY_COUNT).map((a) => a.h),
    pages: anchored,
    map: {
      ...map,
      fields: map.fields.map((f) => ({ ...f, currently_filled: false })),
    },
    createdAt: new Date(),
  };
  await db.collection('formMaps').doc(jobId).set(form);
}

const FIELD_KEYS = [
  'id',
  'page',
  'section',
  'label',
  'kind',
  'filled_by',
  'choice_group',
  'role',
  'group_title',
  'depends_on',
  'continues',
  'default_checked',
  'box',
];

/**
 * The agent saved their review: store their corrected fields, counting
 * toward the cache. Only the agent who imported it can confirm it.
 */
export async function confirmCached(
  db: Firestore,
  jobId: string,
  uid: string,
  fields: Record<string, unknown>[]
): Promise<boolean> {
  const ref = db.collection('formMaps').doc(jobId);
  const doc = await ref.get();
  const form = doc.data() as CachedForm | undefined;
  if (!form || form.ownerUid !== uid) return false;
  if (!Array.isArray(fields) || !fields.length || fields.length > 400) {
    return false;
  }
  const clean = fields.map((f) => {
    const out: Record<string, unknown> = { currently_filled: false };
    for (const k of FIELD_KEYS) if (k in f) out[k] = f[k];
    const box = out.box;
    if (!Array.isArray(box) || box.length !== 4) out.box = [0, 0, 0, 0];
    else out.box = box.map((v) => Math.round(Number(v) || 0));
    return out;
  });
  await ref.update({
    'map.fields': clean,
    confirmed: true,
    confirmedAt: new Date(),
  });
  return true;
}
