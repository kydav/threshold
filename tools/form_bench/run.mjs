// Sends each prepared form through the app's real mapping
// (functions/lib/mapFields.js mapPacket: same model, prompt, settings and,
// past 12 pages, the same split into parts) and saves the field map,
// timing and token usage.
//
// Usage: node run.mjs OUT_DIR [name-filter]
// Needs ANTHROPIC_API_KEY, and `npm run build` in functions/ first.

import { readdirSync, readFileSync, writeFileSync, existsSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const require = createRequire(join(here, '../../functions/package.json'));
const Anthropic = require('@anthropic-ai/sdk').default;
const { mapPacket } = require('./lib/mapFields.js');

// $ per million tokens for claude-opus-5-5.
const PRICE = { input: 4, output: 20 };

const [outDir, filter = ''] = process.argv.slice(2);
if (!process.env.ANTHROPIC_API_KEY) {
  console.error('Set ANTHROPIC_API_KEY first.');
  process.exit(1);
}
const client = new Anthropic();

const names = readdirSync(outDir).filter(
  (n) => n.includes(filter) && existsSync(join(outDir, n, 'pages.json'))
);

async function one(name) {
  const dir = join(outDir, name);
  if (existsSync(join(dir, 'map.json'))) return console.log(`skip ${name}`);
  const { pages } = JSON.parse(readFileSync(join(dir, 'pages.json'), 'utf8'));
  const t0 = Date.now();
  try {
    const { map, usage: u } = await mapPacket(client, pages);
    const cost = (u.input_tokens * PRICE.input + u.output_tokens * PRICE.output) / 1e6;
    writeFileSync(join(dir, 'map.json'), JSON.stringify(map, null, 1));
    writeFileSync(
      join(dir, 'run.json'),
      JSON.stringify({
        model: u.model,
        parts: u.parts,
        seconds: (Date.now() - t0) / 1000,
        input_tokens: u.input_tokens,
        output_tokens: u.output_tokens,
        cost_usd: Number(cost.toFixed(3)),
      })
    );
    console.log(`${name}: ${map.fields.length} fields, ${((Date.now() - t0) / 1000).toFixed(0)}s, $${cost.toFixed(2)}`);
  } catch (e) {
    writeFileSync(join(dir, 'error.txt'), String(e?.stack ?? e));
    console.log(`${name}: FAILED ${e?.message ?? e}`);
  }
}

// A few at a time: each read takes a minute or two.
const queue = [...names];
await Promise.all(
  Array.from({ length: 4 }, async () => {
    while (queue.length) await one(queue.shift());
  })
);
