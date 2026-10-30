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

Each page comes with its exact pixel size and the printed text found on it by \
OCR, as lines with [x0, y0, x1, y1] pixel boxes. Use those boxes to place \
fields exactly: a blank's position follows from the printed words around it \
(for example, the blank that ends just left of "(the \\"Company\\")").

For each field return:
- id: short snake_case name, unique across the form (buyer_name_1, \
end_date_month, fee_percent, buyer_initials_p2).
- page: 1-based page number.
- section: the section number or heading it belongs to ("Header", "1.2", \
"Signatures", "Footer").
- label: what the field is, in plain words a buyer would understand.
- kind: text, date, number, currency, percent, checkbox, signature or initials.
- filled_by: agent_once (the agent's details that never change: brokerage, \
agent name), agent_per_deal (terms set for each buyer: end date, fee, area), \
buyer (anything the buyer writes, initials, signs or dates), agent_sign (the \
agent's or broker's signature and its date).
- choice_group: for "check one" boxes, the same group name on each option; \
empty string otherwise.
- box: [x0, y0, x1, y1] in pixels of that page: the whole area where the value \
goes, from the start of the blank line to its end and from a little above the \
line down to the line itself. Signature and initials boxes should be generous \
enough for a real signature. Never cover printed words.
- currently_filled: true if this copy already has something written, typed or \
checked there.

Include every blank, including ones this copy left empty (a second buyer's \
signature line, an unused property line). A date printed as separate day / \
month / year blanks is separate fields. Leave out printed text that never \
changes.`;

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
