import {
  PDFArray,
  PDFDict,
  PDFDocument,
  PDFName,
  PDFNumber,
  PDFPage,
  PDFRef,
} from 'pdf-lib';
import type { FieldMap } from './mapFields';

/**
 * A PDF's own fillable fields ("widgets"), used to put mapped boxes exactly
 * where the form's author drew them. Only uploaded PDFs have these; scans
 * and flattened PDFs have none, and their boxes are left as the model drew
 * them.
 */
export type WidgetKind = 'text' | 'checkbox' | 'signature';

export interface PdfWidget {
  kind: WidgetKind;
  /** [x0, y0, x1, y1] in pixels of the page image, top-left origin. */
  box: number[];
}

/** Larger PDFs are skipped: their fields are a nicety, not worth the upload. */
export const MAX_PDF_BYTES = 6 * 1024 * 1024;

/**
 * The fillable fields on each page, in page-image pixels. [sizes] are the
 * page images' pixel sizes (the app rasterizes the crop box, top-left
 * origin). Rotated pages are skipped. Never throws: a PDF it can't read
 * just has no fields.
 */
export async function pdfWidgets(
  pdf: Uint8Array,
  sizes: { width: number; height: number }[]
): Promise<PdfWidget[][]> {
  const out: PdfWidget[][] = sizes.map(() => []);
  let pages: PDFPage[];
  try {
    // Field rectangles are plain numbers, so PDFs encrypted with an empty
    // password usually still read; ones whose structure is encrypted too
    // fail here and just have no fields.
    const doc = await PDFDocument.load(pdf, {
      ignoreEncryption: true,
      updateMetadata: false,
      throwOnInvalidObject: false,
    });
    pages = doc.getPages();
  } catch {
    return out;
  }
  for (let i = 0; i < pages.length && i < sizes.length; i++) {
    try {
      const page = pages[i];
      if (page.getRotation().angle % 360 !== 0) continue;
      const crop = page.getCropBox();
      if (!(crop.width > 0 && crop.height > 0)) continue;
      const sx = sizes[i].width / crop.width;
      const sy = sizes[i].height / crop.height;
      const annots = page.node.lookupMaybe(PDFName.of('Annots'), PDFArray);
      if (!annots) continue;
      for (let a = 0; a < annots.size(); a++) {
        const w = annots.lookupMaybe(a, PDFDict);
        if (!w || name(w.get(PDFName.of('Subtype'))) !== 'Widget') continue;
        const kind = widgetKind(w);
        if (!kind) continue;
        const rect = w.lookupMaybe(PDFName.of('Rect'), PDFArray);
        if (!rect || rect.size() !== 4) continue;
        const [x0, y0, x1, y1] = [0, 1, 2, 3].map(
          (n) => rect.lookupMaybe(n, PDFNumber)?.asNumber() ?? NaN
        );
        if ([x0, y0, x1, y1].some((v) => !Number.isFinite(v))) continue;
        // Hidden or zero-size widgets.
        if (Math.abs(x1 - x0) < 2 || Math.abs(y1 - y0) < 2) continue;
        out[i].push({
          kind,
          box: [
            Math.round((Math.min(x0, x1) - crop.x) * sx),
            Math.round((crop.height - (Math.max(y0, y1) - crop.y)) * sy),
            Math.round((Math.max(x0, x1) - crop.x) * sx),
            Math.round((crop.height - (Math.min(y0, y1) - crop.y)) * sy),
          ],
        });
      }
    } catch {
      // One odd page shouldn't cost the others their fields.
    }
  }
  return out;
}

function name(v: unknown): string | undefined {
  return v instanceof PDFName ? v.decodeText() : undefined;
}

/** A field attribute, inherited from parent fields as the PDF spec allows. */
function inherited(dict: PDFDict, key: string): unknown {
  let d: PDFDict | undefined = dict;
  for (let depth = 0; d && depth < 12; depth++) {
    const v = d.get(PDFName.of(key));
    if (v !== undefined) return v instanceof PDFRef ? d.context.lookup(v) : v;
    d = d.lookupMaybe(PDFName.of('Parent'), PDFDict);
  }
  return undefined;
}

function widgetKind(w: PDFDict): WidgetKind | null {
  const ft = name(inherited(w, 'FT'));
  const ffRaw = inherited(w, 'Ff');
  const ff = ffRaw instanceof PDFNumber ? ffRaw.asNumber() : 0;
  switch (ft) {
    case 'Tx':
    case 'Ch':
      return 'text';
    case 'Sig':
      return 'signature';
    case 'Btn':
      return ff & (1 << 16) ? null : 'checkbox'; // push buttons aren't fields
    default:
      return null;
  }
}

type Box = number[];

const area = (b: Box) =>
  Math.max(0, b[2] - b[0]) * Math.max(0, b[3] - b[1]);
const inter = (a: Box, b: Box) =>
  area([
    Math.max(a[0], b[0]),
    Math.max(a[1], b[1]),
    Math.min(a[2], b[2]),
    Math.min(a[3], b[3]),
  ]);

/**
 * Moves each mapped box onto the PDF field it clearly sits on. A box is
 * only moved when it sits on exactly one PDF field (a box the model drew
 * across two, like all buyers' names over the Buyer 1 and Buyer 2 blanks,
 * stays as drawn), exactly one mapped field claims that PDF field (a date
 * the model split into day/month/year over one PDF field stays split),
 * the kinds agree (checkbox to checkbox) and the sizes are comparable.
 * Returns how many boxes moved.
 */
export function snapToPdfFields(map: FieldMap, widgets: PdfWidget[][]): number {
  if (!widgets.some((p) => p.length)) return 0;
  const best = new Map<number, { page: number; w: number }>();
  const claims = new Map<string, number>();
  map.fields.forEach((f, i) => {
    const box = f.box as Box;
    const page = (f.page as number) - 1;
    const onPage = widgets[page];
    if (!onPage?.length || !Array.isArray(box) || box.length !== 4) return;
    const fieldIsCheck = f.kind === 'checkbox';
    let top = -1;
    let topIou = 0;
    let onCount = 0;
    onPage.forEach((w, n) => {
      if ((w.kind === 'checkbox') !== fieldIsCheck) return;
      const i2 = inter(box, w.box);
      if (!i2) return;
      const a = area(box);
      const b = area(w.box);
      if (i2 / Math.max(1, Math.min(a, b)) < 0.4) return;
      onCount++;
      const ratio = b / Math.max(1, a);
      if (ratio > 5 || ratio < 0.2) return;
      const iou = i2 / (a + b - i2);
      if (iou > topIou) {
        topIou = iou;
        top = n;
      }
    });
    if (top < 0 || onCount > 1) return;
    best.set(i, { page, w: top });
    const key = `${page}:${top}`;
    claims.set(key, (claims.get(key) ?? 0) + 1);
  });
  let moved = 0;
  for (const [i, { page, w }] of best) {
    if (claims.get(`${page}:${w}`) !== 1) continue;
    map.fields[i].box = [...widgets[page][w].box];
    moved++;
  }
  return moved;
}
