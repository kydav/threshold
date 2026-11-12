import Anthropic from '@anthropic-ai/sdk';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { defineSecret } from 'firebase-functions/params';

export const anthropicApiKey = defineSecret('ANTHROPIC_API_KEY');

// Mapping runs once per template (not per deal), so it uses the most capable
// model: accuracy here is what every later signing depends on.
const MODEL = 'claude-opus-5-5';

export interface OcrWord {
  text: string;
  /** [x0, y0, x1, y1] in page-image pixels. */
  box: number[];
}

export interface PageInput {
  /** JPEG of the flattened page, base64. Long edge <= 1568 px. */
  jpegBase64: string;
  width: number;
  height: number;
  /** On-device OCR lines, used to anchor field positions to real text. */
  ocr: OcrWord[];
}

const KINDS = [
  'text',
  'date',
  'number',
  'currency',
  'percent',
  'checkbox',
  'signature',
  'initials',
];
const FILLERS = ['agent_once', 'agent_per_deal', 'buyer', 'agent_sign'];

// What a field *is*, so the app can fill it or skip asking: names come from
// the buyers the agent already entered, agent details from their profile,
// dates from today.
const ROLES = [
  'buyer_names', // all buyers' names on one blank ("... (the Buyer)")
  'buyer1_name',
  'buyer2_name',
  'buyer_email',
  'buyer_address_phone',
  'brokerage_name',
  'agent_name',
  'agent_license',
  'end_date',
  'start_date',
  'fee_amount',
  'fee_percent',
  'protection_months',
  'area',
  'property_address',
  'excluded_properties',
  'signature',
  'initials',
  'sign_date',
  'other',
];

const SCHEMA = {
  type: 'object',
  properties: {
    form_title: { type: 'string' },
    form_id: { type: 'string' },
    summary: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          text: { type: 'string' },
          if_checked: { type: 'string' },
        },
        required: ['text', 'if_checked'],
        additionalProperties: false,
      },
    },
    fields: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          id: { type: 'string' },
          page: { type: 'integer' },
          section: { type: 'string' },
          label: { type: 'string' },
          kind: { type: 'string', enum: KINDS },
          filled_by: { type: 'string', enum: FILLERS },
          choice_group: { type: 'string' },
          role: { type: 'string', enum: ROLES },
          group_title: { type: 'string' },
          depends_on: { type: 'string' },
          continues: { type: 'string' },
          default_checked: { type: 'boolean' },
          box: { type: 'array', items: { type: 'integer' } },
          currently_filled: { type: 'boolean' },
        },
        required: [
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
          'currently_filled',
        ],
        additionalProperties: false,
      },
    },
  },
  required: ['form_title', 'form_id', 'summary', 'fields'],
  additionalProperties: false,
} as const;

const PROMPT = `These are the pages of a real estate buyer-broker agreement, \
in order. An agent will reuse this form as a template: our app fills the \
blanks and collects e-signatures, so we need a precise map of every place \
someone writes, checks a box, initials or signs.

The agent fills this in on their phone at a showing, in under a minute, then \
hands the phone to the buyer to sign. So besides WHERE each field is, tell us \
what it MEANS and how fields relate, so the app can fill what it already \
knows, hide what doesn't apply, and ask only real questions, grouped.

Each page comes with its exact pixel size and the printed text found on it by \
OCR, as lines with [x0, y0, x1, y1] pixel boxes. Use those boxes to place \
fields exactly: a blank's position follows from the printed words around it \
(for example, the blank that ends just left of "(the \\"Company\\")").

For each field return:
- id: short snake_case name, unique across the form (buyer_names, \
end_date_month, rep_area_county, county_names, fee_percent, buyer_initials_p2).
- page: 1-based page number.
- section: the section number or heading it belongs to ("Header", "1.2", \
"Signatures", "Footer").
- label: a SHORT plain-words label for the input, 1-5 words, as a buyer would \
say it: "Counties", "Property address", "End date", "Fee (%)", "Protection \
period (months)". For a checkbox option, the option itself in a few words: \
"Specific counties", "Specific properties", "Shall go to mediation", "May go \
to mediation", "Has an addendum", "No addendum". Never start with "Check:".
- kind: text, date, number, currency, percent, checkbox, signature or initials.
- filled_by: agent_once (the agent's details that never change: brokerage, \
agent name, license), agent_per_deal (everything decided or written when the \
agent sits down with the buyer: names, end date, area, fee, exclusions, \
mediation, addendum, other-brokerage disclosures — even facts about the \
buyer, because the agent fills these in with the buyer before handing over), \
buyer (only what the buyer does themselves at signing: signatures, initials, \
the dates beside them, and their own address/phone/email lines in the \
signature block), agent_sign (the agent's or broker's acceptance signature \
and its date). A checkbox and the blanks that complete it always share the \
same filled_by.
- choice_group: for "check one" options, the same group name on each option \
(e.g. "rep_area" on both the county and property options); empty otherwise. \
A single checkbox that can be checked or not is NOT a choice group.
- role: what the field is: buyer_names (one blank naming all buyers, e.g. \
"... and ______ (the Buyer)"), buyer1_name, buyer2_name, buyer_email, \
buyer_address_phone, brokerage_name, agent_name, agent_license, end_date, \
start_date, fee_amount, fee_percent, protection_months, area (counties, \
cities, areas), property_address, excluded_properties, signature, initials, \
sign_date (a date beside a signature or initials), or other.
- group_title: a short question or heading that groups related fields on the \
fill-out screen, the same text on every field of the group: "Who", \
"How long", "Where you represent the buyer", "Other brokerage agreements", \
"Brokerage fee", "Protection period", "Mediation", "Addendum", \
"Signatures". Options of one choice group, and the blanks that belong to \
those options, share one group_title.
- depends_on: the id of the checkbox option this field only applies to, or \
empty. The blank after "[ ] located only within: ____ (County/Counties)" \
depends on that county option; the property-address lines depend on the \
property option; the excluded-properties lines depend on the "Buyer does have \
a representation agreement with another brokerage" checkbox. The app shows \
these only once that box is checked.
- continues: if this blank is a continuation line of the previous blank's \
answer (a long answer wrapping onto a second or third line), the id of the \
line it continues (line 2 continues line 1, line 3 continues line 2); empty \
otherwise. The app asks once and wraps the text across the lines.
- default_checked: true for the option the form says applies when nothing is \
checked (e.g. "If no box is checked, then ... shall be the default"), and for \
the option that is by far the usual choice (e.g. "there ARE NOT additional \
terms in an Addendum"); false otherwise and for non-checkboxes.
- box: [x0, y0, x1, y1] in pixels of that page: the whole area where the value \
goes, from the start of the blank line to its end and from a little above the \
line down to the line itself. Signature and initials boxes should be generous \
enough for a real signature. Never cover printed words.
- currently_filled: true if this copy already has something written, typed or \
checked there.

Also return summary: a short plain-English overview of this agreement that the app shows the buyer above the form before they sign, filled in with the deal's own values. 4 to 7 sentences, each its own item, in the order a buyer would want: who they're hiring and for how long, where/which properties, what they'll owe and when, how long the protection period lasts, and any notable commitment (exclusivity, mediation, attorney fees, class-action waiver). Write to the buyer as "you". Neutral and factual: describe what the form says, never advise. Put a field's value in a sentence with {field_id} (an id from your fields), e.g. "This agreement ends on {end_date}." For a date split into day/month/year blanks, use {<base>_date} (e.g. {end_date} for end_date_day/end_date_month/end_date_year). if_checked: the id of a checkbox option the sentence only applies to (e.g. the county sentence uses the county option's id, the property sentence the property option's id), else empty. Don't mention buyer names (the app greets them).

Include every blank, including ones this copy left empty (a second buyer's \
signature line, an unused property line). A date printed as separate day / \
month / year blanks is separate fields with the same group_title. Leave out \
printed text that never changes, and footers printed by forms software \
(brokerage address, transaction name) that aren't blanks.`;

/** The JSON field map Claude returns (shape: SCHEMA). */
export type FieldMap = {
  form_title: string;
  form_id: string;
  summary: { text: string; if_checked: string }[];
  fields: Record<string, unknown>[];
};

/** Packets up to this many pages are read in one request, as before. */
export const SINGLE_READ_PAGES = 12;
/** Longer packets are read in parts of at most this many pages, at once. */
const PART_PAGES = 8;
/** The most pages one import takes. */
export const MAX_PAGES = 30;

/**
 * Reads the pages with Claude and returns the field map. Throws HttpsError
 * on a refusal, an over-long form or an empty answer.
 */
export async function mapPages(
  pages: PageInput[],
  apiKey: string
): Promise<FieldMap> {
  return (await mapPacket(new Anthropic({ apiKey }), pages)).map;
}

/** Tokens a read used, summed over its parts. */
export interface ReadUsage {
  model: string;
  input_tokens: number;
  output_tokens: number;
  parts: number;
}

/**
 * Reads a packet. Up to [SINGLE_READ_PAGES] pages go in one request. A
 * longer one (a form plus addenda) would take longer than the server
 * allows and could outgrow one answer, so it's read in parts of up to
 * [PART_PAGES] pages at the same time and the parts are merged.
 */
export async function mapPacket(
  client: Anthropic,
  pages: PageInput[]
): Promise<{ map: FieldMap; usage: ReadUsage }> {
  const parts: PageInput[][] = [];
  if (pages.length <= SINGLE_READ_PAGES) {
    parts.push(pages);
  } else {
    const count = Math.ceil(pages.length / PART_PAGES);
    const size = Math.ceil(pages.length / count);
    for (let i = 0; i < pages.length; i += size) {
      parts.push(pages.slice(i, i + size));
    }
  }
  let first = 1;
  const reads = parts.map((part) => {
    const range =
      parts.length > 1
        ? { first, last: first + part.length - 1, total: pages.length }
        : undefined;
    first += part.length;
    return client.beta.messages.stream(mapRequest(part, range)).finalMessage();
  });
  const responses = await Promise.all(reads);
  const maps = responses.map(parseMapResponse);
  return {
    map: maps.length === 1 ? maps[0] : mergeParts(maps, parts),
    usage: {
      model: responses[0].model,
      input_tokens: responses.reduce((s, r) => s + r.usage.input_tokens, 0),
      output_tokens: responses.reduce((s, r) => s + r.usage.output_tokens, 0),
      parts: parts.length,
    },
  };
}

/**
 * One map from the maps of consecutive parts. Pages are renumbered to the
 * whole packet; an id another part already used gets a page suffix (and
 * that part's links and summary follow the rename). The title and summary
 * come from the part holding the agreement's term, since that's the main
 * agreement and not a disclosure or addendum; failing that, the part with
 * the most fields.
 */
export function mergeParts(maps: FieldMap[], parts: PageInput[][]): FieldMap {
  const used = new Set<string>();
  const renamed: Map<string, string>[] = [];
  const fields: Record<string, unknown>[] = [];
  let offset = 0;
  maps.forEach((m, n) => {
    const rename = new Map<string, string>();
    for (const f of m.fields) {
      const id = String(f.id);
      let next = id;
      for (let k = 2; used.has(next); k++) {
        next = `${id}_p${Number(f.page) + offset}${k > 2 ? `_${k}` : ''}`;
      }
      used.add(next);
      if (next !== id) rename.set(id, next);
    }
    const fix = (v: unknown) =>
      typeof v === 'string' && rename.has(v) ? rename.get(v)! : v;
    for (const f of m.fields) {
      fields.push({
        ...f,
        id: fix(f.id),
        page: Number(f.page) + offset,
        depends_on: fix(f.depends_on),
        continues: fix(f.continues),
      });
    }
    renamed.push(rename);
    offset += parts[n].length;
  });

  let main = maps.findIndex((m) =>
    m.fields.some((f) => f.role === 'end_date')
  );
  if (main < 0) {
    main = maps.reduce(
      (best, m, i) => (m.fields.length > maps[best].fields.length ? i : best),
      0
    );
  }
  const rename = renamed[main];
  const summary = maps[main].summary.map((line) => ({
    text: line.text.replace(/\{(\w+)\}/g, (all, id: string) =>
      rename.has(id) ? `{${rename.get(id)}}` : all
    ),
    if_checked: rename.get(line.if_checked) ?? line.if_checked,
  }));
  return {
    form_title: maps[main].form_title,
    form_id: maps[main].form_id,
    summary,
    fields,
  };
}

/**
 * The exact request mapPages sends. Exported so the form bench
 * (tools/form_bench) tests the same model, prompt and settings.
 */
export function mapRequest(
  pages: PageInput[],
  range?: { first: number; last: number; total: number }
): Anthropic.Beta.MessageCreateParamsStreaming {
  const content: Anthropic.Beta.BetaContentBlockParam[] = [];
  if (range) {
    content.push({
      type: 'text',
      text:
        `These are pages ${range.first} to ${range.last} of a ` +
        `${range.total}-page packet; the other pages are read separately. ` +
        'Number pages from 1 as they appear here. A page may continue a ' +
        'form that starts before these or be a separate addendum or ' +
        'disclosure: map every blank either way, and write the summary ' +
        'about the agreement these pages belong to.',
    });
  }
  pages.forEach((p, i) => {
    const ocr = p.ocr
      .map((w) => `${JSON.stringify(w.text)} ${JSON.stringify(w.box)}`)
      .join('\n');
    content.push({
      type: 'text',
      text: `Page ${i + 1}: ${p.width}x${p.height} pixels. OCR lines:\n${ocr}`,
    });
    content.push({
      type: 'image',
      source: {
        type: 'base64',
        media_type: 'image/jpeg',
        data: p.jpegBase64,
      },
    });
  });
  content.push({ type: 'text', text: PROMPT });

  return {
    stream: true,
    model: MODEL,
    max_tokens: 64000,
    thinking: { type: 'adaptive' },
    output_config: {
      effort: 'high',
      format: { type: 'json_schema', schema: SCHEMA },
    },
    betas: ['server-side-fallback-2026-07-01'],
    fallbacks: 'default',
    messages: [{ role: 'user', content }],
  };
}

/** The field map from a finished response, or an HttpsError. */
export function parseMapResponse(response: Anthropic.Beta.BetaMessage): FieldMap {
  if (response.stop_reason === 'refusal') {
    throw new HttpsError('failed-precondition', 'The form could not be read.');
  }
  if (response.stop_reason === 'max_tokens') {
    throw new HttpsError('resource-exhausted', 'The form was too long to map.');
  }
  const text = response.content.find((b) => b.type === 'text');
  if (!text || text.type !== 'text') {
    throw new HttpsError('internal', 'No field map came back.');
  }
  return JSON.parse(text.text) as FieldMap;
}

/** Pages a client sent, checked: 1 to [MAX_PAGES] pages, each with an image and size. */
export function validPages(data: unknown): PageInput[] {
  const pages = ((data as { pages?: unknown })?.pages ?? []) as PageInput[];
  if (!Array.isArray(pages) || !pages.length || pages.length > MAX_PAGES) {
    throw new HttpsError('invalid-argument', `Send 1-${MAX_PAGES} pages.`);
  }
  for (const p of pages) {
    if (
      typeof p?.jpegBase64 !== 'string' ||
      !(p.width > 0) ||
      !(p.height > 0) ||
      !Array.isArray(p.ocr)
    ) {
      throw new HttpsError('invalid-argument', 'A page is incomplete.');
    }
  }
  return pages;
}

/**
 * The original one-shot mapping, kept for app versions before background
 * imports (1.2.x). The phone waits on the open connection for the answer.
 */
export const mapFormFields = onCall(
  {
    secrets: [anthropicApiKey],
    region: 'us-central1',
    timeoutSeconds: 300,
    memory: '512MiB',
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Sign in to map a form.');
    }
    return mapPages(validPages(request.data), anthropicApiKey.value());
  }
);
