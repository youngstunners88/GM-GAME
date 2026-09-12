#!/usr/bin/env node
/**
 * split-scene-kit.mjs — split a DeepSeek scene-kit reply into repo files.
 *
 * Usage: node scripts/split-scene-kit.mjs <reply.md> <out-dir>
 *
 * The scene briefs ask the model to emit `===== FILE: NAME.md =====` headings
 * precisely so this split is mechanical rather than a hand-copy. Hand-copying
 * model output into a repo is how a claim nobody checked becomes a document
 * everybody trusts.
 *
 * Every written file keeps the or-call.mjs provenance header AND gets a
 * verification banner, because a scene kit is unvalidated model output until a
 * human or Claude checks it against the code it describes.
 */
import { readFileSync, writeFileSync, mkdirSync, existsSync } from 'fs';
import { join } from 'path';

const [SRC, OUT] = process.argv.slice(2);
if (!SRC || !OUT) { console.error('Usage: split-scene-kit.mjs <reply.md> <out-dir>'); process.exit(1); }
if (!existsSync(SRC)) { console.error(`ERROR: no such reply file: ${SRC}`); process.exit(2); }
mkdirSync(OUT, { recursive: true });

const raw = readFileSync(SRC, 'utf-8');
const header = (raw.match(/^<!--[\s\S]*?-->/) || [''])[0];

const parts = raw.split(/^#{0,6}\s*=====\s*FILE:\s*(.+?)\s*=====\s*$/m);
if (parts.length < 3) {
  console.error('ERROR: no "===== FILE: x =====" markers found.');
  console.error('  The model did not follow the output contract; re-dispatch rather than');
  console.error('  hand-splitting, or the kit stops being reproducible.');
  process.exit(3);
}

const BANNER = `> **UNVALIDATED MODEL OUTPUT until checked.** Authored by DeepSeek via
> OpenRouter from the founder reference images and the shipped Godot
> implementation. Claude's verification notes are in \`_VERIFICATION.md\` in this
> folder — read that before treating any number here as fact.

`;

let written = 0;
for (let i = 1; i < parts.length; i += 2) {
  const name = parts[i].trim().replace(/[^A-Za-z0-9_.-]/g, '_');
  const body = parts[i + 1].trim();
  writeFileSync(join(OUT, name), `${header}\n\n${BANNER}${body}\n`);
  console.log(`  wrote ${join(OUT, name)} (${body.split('\n').length} lines)`);
  written++;
}
console.log(`${written} file(s) written to ${OUT}`);
