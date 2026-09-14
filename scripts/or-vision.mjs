#!/usr/bin/env node
/**
 * or-vision.mjs — DEPRECATED SHIM. Forwards to `or-call.mjs --image`.
 *
 * This file used to be a second, standalone OpenRouter client that existed
 * only because or-call.mjs could not carry an image. On 2026-09-10 image
 * support moved INTO or-call.mjs (`--image <path>`, repeatable), so keeping
 * two clients would mean two places for the same bug — the failure this repo
 * already writes down as a rule for the security sentinel ("exactly one
 * implementation, not three copies that can drift").
 *
 * The merged client is strictly better than what was here, and the difference
 * is not cosmetic:
 *   * HTTPS_PROXY / undici ProxyAgent — WITHOUT this the call gets a hard 403
 *     from this sandbox's egress proxy. The old standalone had no proxy
 *     handling at all, so it could not have worked in a cloud session.
 *   * live /models pricing + --dry-run — STATUS.md itself flagged the old
 *     script's missing cost figure as "not tracked ... flagging honestly
 *     rather than inventing a number". Now it is tracked.
 *   * input-modality guard — sending an image to a text-only model does not
 *     error; the model answers from the text and it reads like a real visual
 *     review. That is now caught before spending.
 *   * empty-content diagnosis for reasoning models, and @include expansion.
 *
 * The old argument order is preserved so nothing that called this breaks.
 *
 * Usage (unchanged):  node scripts/or-vision.mjs <model> <prompt-file> <out-file> <img...>
 * Preferred:          node scripts/or-call.mjs <model> <prompt-file> <out-file> --image <img> ...
 */
import { spawnSync } from 'child_process';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const [MODEL, PROMPT_FILE, OUT_FILE, ...IMAGES] = process.argv.slice(2);
if (!MODEL || !PROMPT_FILE || !OUT_FILE || IMAGES.length === 0) {
  console.error('Usage: or-vision.mjs <model> <prompt-file> <out-file> <img...>');
  console.error('(deprecated — prefer: or-call.mjs <model> <prompt-file> <out-file> --image <img> ...)');
  process.exit(1);
}

console.error('NOTE: or-vision.mjs is a shim; dispatching via or-call.mjs --image');

const here = dirname(fileURLToPath(import.meta.url));
const args = [join(here, 'or-call.mjs'), MODEL, PROMPT_FILE, OUT_FILE];
for (const img of IMAGES) args.push('--image', img);

const r = spawnSync(process.execPath, args, { stdio: 'inherit' });
process.exit(r.status ?? 1);
