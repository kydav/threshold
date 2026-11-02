import Anthropic from '@anthropic-ai/sdk';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { defineSecret } from 'firebase-functions/params';

const anthropicApiKey = defineSecret('ANTHROPIC_API_KEY');

// Mapping runs once per template (not per deal), so it uses the most capable
// model: accuracy here is what every later signing depends on.
const MODEL = 'claude-opus-5';

interface OcrWord {
  text: string;
  /** [x0, y0, x1, y1] in page-image pixels. */
  box: number[];
}

interface PageInput {
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
  required: ['form_title', 'form_id', 'fields'],
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

Include every blank, including ones this copy left empty (a second buyer's \
signature line, an unused property line). A date printed as separate day / \
month / year blanks is separate fields with the same group_title. Leave out \
printed text that never changes, and footers printed by forms software \
(brokerage address, transaction name) that aren't blanks.`;

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
    const pages = (request.data?.pages ?? []) as PageInput[];
    if (!pages.length || pages.length > 12) {
      throw new HttpsError('invalid-argument', 'Send 1-12 pages.');
    }

    const content: Anthropic.Beta.BetaContentBlockParam[] = [];
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

    const client = new Anthropic({ apiKey: anthropicApiKey.value() });
    const stream = client.beta.messages.stream({
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
    });
    const response = await stream.finalMessage();

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
    return JSON.parse(text.text);
  }
);
