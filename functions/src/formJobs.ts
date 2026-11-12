import * as admin from 'firebase-admin';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { logger } from 'firebase-functions/v2';
import { confirmCached, findCached, saveCandidate } from './formCache';
import { anthropicApiKey, mapPages, PageInput, validPages } from './mapFields';
import { MAX_PDF_BYTES, PdfWidget, pdfWidgets, snapToPdfFields } from './pdfFields';

/**
 * Background form imports. Reading a form takes a minute or more, longer
 * than a phone keeps a connection open once the agent leaves the app. So:
 *
 *  1. startFormMapping stores the pages and a queued job, then returns at
 *     once. A form that 3 different agents already imported and
 *     reviewed comes straight back from the cache instead.
 *  2. processFormJob (Firestore trigger) reads the form and saves the
 *     result on the job.
 *  3. The app polls getFormJob, now or the next time it's opened.
 *  4. confirmFormMap: the agent saved their review, which counts toward
 *     the form being offered to others from the cache.
 *
 * Jobs live in formJobs/{jobId}; the page images, OCR and the PDF's own
 * field boxes in its "chunks" subcollection until the job finishes. Clients reach them only through
 * these functions (no client Firestore rules involved).
 */

const db = () => admin.firestore();
const REGION = 'us-central1';
/** Firestore's document limit is 1 MiB; page images are split below it. */
const CHUNK = 900 * 1024;

type JobStatus = 'queued' | 'running' | 'done' | 'error';

interface PageMeta {
  width: number;
  height: number;
  /** Image chunk count. */
  chunks: number;
  /** Older jobs kept OCR here; newer ones in page_<i> (1 MiB doc limit). */
  ocr?: PageInput['ocr'];
}

/** Per-page doc: OCR lines and, for uploaded PDFs, its fillable fields. */
interface PageExtras {
  ocr: PageInput['ocr'];
  widgets?: PdfWidget[];
}

/** An uploaded PDF's fields per page, or nothing for scans / bad input. */
async function widgetsFrom(
  data: unknown,
  pages: PageInput[]
): Promise<PdfWidget[][] | null> {
  const b64 = (data as { pdfBase64?: unknown })?.pdfBase64;
  if (typeof b64 !== 'string' || !b64) return null;
  const pdf = Buffer.from(b64, 'base64');
  if (!pdf.length || pdf.length > MAX_PDF_BYTES) return null;
  try {
    const widgets = await pdfWidgets(pdf, pages);
    return widgets.some((p) => p.length) ? widgets : null;
  } catch (e) {
    logger.warn('Could not read the PDF fields', e);
    return null;
  }
}

export const startFormMapping = onCall(
  // Up to 30 page images plus a PDF arrive in one call.
  { region: REGION, timeoutSeconds: 120, memory: '1GiB' },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError('unauthenticated', 'Sign in to add a form.');
    const pages = validPages(request.data);
    const job = db().collection('formJobs').doc();

    let cached: Awaited<ReturnType<typeof findCached>> = null;
    try {
      cached = await findCached(db(), pages);
    } catch (e) {
      logger.warn('Form cache lookup failed', e);
    }
    if (cached) {
      await job.set({
        uid,
        status: 'done' as JobStatus,
        cached: true,
        sourceId: cached.sourceId,
        result: cached.map,
        createdAt: new Date(),
        finishedAt: new Date(),
      });
      return { jobId: job.id, status: 'done', cached: true, result: cached.map };
    }

    const widgets = await widgetsFrom(request.data, pages);

    // The pages first: the trigger on the job reads them.
    const meta: PageMeta[] = [];
    const writes: Promise<unknown>[] = [];
    pages.forEach((p, i) => {
      const jpeg = Buffer.from(p.jpegBase64, 'base64');
      const count = Math.max(1, Math.ceil(jpeg.length / CHUNK));
      for (let n = 0; n < count; n++) {
        writes.push(
          job
            .collection('chunks')
            .doc(`${i}_${n}`)
            .set({ page: i, n, data: jpeg.subarray(n * CHUNK, (n + 1) * CHUNK) })
        );
      }
      meta.push({ width: p.width, height: p.height, chunks: count });
      const extras: PageExtras = { ocr: p.ocr };
      if (widgets?.[i]?.length) extras.widgets = widgets[i];
      writes.push(job.collection('chunks').doc(`page_${i}`).set(extras));
    });
    writes.push(job.collection('chunks').doc('meta').set({ pages: meta }));
    await Promise.all(writes);

    await job.set({
      uid,
      status: 'queued' as JobStatus,
      pageCount: pages.length,
      createdAt: new Date(),
    });
    return { jobId: job.id, status: 'queued' };
  }
);

export const processFormJob = onDocumentCreated(
  {
    document: 'formJobs/{jobId}',
    region: REGION,
    secrets: [anthropicApiKey],
    timeoutSeconds: 540,
    memory: '1GiB',
    retry: false,
  },
  async (event) => {
    const snap = event.data;
    const job = snap?.data();
    if (!snap || job?.status !== 'queued') return;
    const ref = snap.ref;
    await ref.update({ status: 'running' as JobStatus, startedAt: new Date() });
    const chunks = ref.collection('chunks');
    try {
      const metaDoc = await chunks.doc('meta').get();
      const meta = (metaDoc.data()?.pages ?? []) as PageMeta[];
      const pages: PageInput[] = [];
      const widgets: PdfWidget[][] = [];
      for (let i = 0; i < meta.length; i++) {
        const [extrasDoc, ...parts] = await Promise.all([
          chunks.doc(`page_${i}`).get(),
          ...Array.from({ length: meta[i].chunks }, (_, n) =>
            chunks.doc(`${i}_${n}`).get()
          ),
        ]);
        const extras = extrasDoc.data() as PageExtras | undefined;
        widgets.push(extras?.widgets ?? []);
        const jpeg = Buffer.concat(
          parts.map((d) => Buffer.from(d.data()?.data as Uint8Array))
        );
        pages.push({
          jpegBase64: jpeg.toString('base64'),
          width: meta[i].width,
          height: meta[i].height,
          ocr: extras?.ocr ?? meta[i].ocr ?? [],
        });
      }

      const map = await mapPages(pages, anthropicApiKey.value());
      // An uploaded PDF's own fields are exactly placed; use them.
      const snapped = snapToPdfFields(map, widgets);
      if (snapped) logger.info(`Snapped ${snapped} boxes to PDF fields`);
      try {
        await saveCandidate(db(), event.params.jobId, job.uid, pages, map);
      } catch (e) {
        logger.warn('Could not save the form as a cache candidate', e);
      }
      await ref.update({
        status: 'done' as JobStatus,
        result: map,
        finishedAt: new Date(),
      });
    } catch (e) {
      logger.error('Form mapping failed', e);
      await ref.update({
        status: 'error' as JobStatus,
        error:
          e instanceof HttpsError
            ? e.message
            : 'Could not read the form. Please try again.',
        finishedAt: new Date(),
      });
    } finally {
      await db().recursiveDelete(chunks);
    }
  }
);

async function ownJob(uid: string | undefined, jobId: unknown) {
  if (!uid) throw new HttpsError('unauthenticated', 'Sign in first.');
  if (typeof jobId !== 'string' || !jobId) {
    throw new HttpsError('invalid-argument', 'Missing jobId.');
  }
  const doc = await db().collection('formJobs').doc(jobId).get();
  if (!doc.exists || doc.data()?.uid !== uid) {
    throw new HttpsError('not-found', 'That form import was not found.');
  }
  return doc;
}

export const getFormJob = onCall({ region: REGION }, async (request) => {
  const doc = await ownJob(request.auth?.uid, request.data?.jobId);
  const job = doc.data()!;
  const status = job.status as JobStatus;
  return {
    status,
    cached: job.cached === true,
    ...(status === 'done' ? { result: job.result } : {}),
    ...(status === 'error' ? { error: job.error } : {}),
  };
});

export const confirmFormMap = onCall({ region: REGION }, async (request) => {
  const uid = request.auth?.uid;
  const doc = await ownJob(uid, request.data?.jobId);
  // A form that came from the cache is already confirmed by someone else.
  if (doc.data()?.cached) return { confirmed: false };
  const confirmed = await confirmCached(
    db(),
    doc.id,
    uid!,
    request.data?.fields as Record<string, unknown>[]
  );
  return { confirmed };
});
