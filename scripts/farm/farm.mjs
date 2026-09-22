#!/usr/bin/env node
// Tool Farm CLI — validate / list / why / route-table
//
// Zero dependencies on purpose: this is the gate that guards the toolchain, so
// it must not itself pull a supply chain. Implements the draft-07 subset our
// schemas actually use, and fails CLOSED — an unrecognised keyword is an error,
// never a silent pass. That is the whole point of "typesafe" here: a malformed
// registry stops the build instead of quietly routing work to the wrong tier.
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const KNOWN = new Set(['$schema', '$id', 'title', 'description', 'type', 'required',
  'properties', 'additionalProperties', 'items', 'enum', 'pattern', 'minLength',
  'minItems', 'minProperties', 'minimum']);

function typeOf(v) {
  if (v === null) return 'null';
  if (Array.isArray(v)) return 'array';
  if (Number.isInteger(v)) return 'integer';
  return typeof v;
}

function validate(value, schema, path, errs) {
  for (const k of Object.keys(schema)) {
    if (!KNOWN.has(k)) errs.push(`${path}: schema uses unsupported keyword "${k}" — validator fails closed`);
  }
  if (schema.type) {
    const t = typeOf(value);
    const ok = schema.type === 'number' ? (t === 'number' || t === 'integer')
      : schema.type === 'object' ? t === 'object'
      : t === schema.type;
    if (!ok) { errs.push(`${path}: expected ${schema.type}, got ${t}`); return; }
  }
  if (schema.enum && !schema.enum.includes(value)) {
    errs.push(`${path}: ${JSON.stringify(value)} is not one of [${schema.enum.join(', ')}]`);
  }
  if (schema.pattern && typeof value === 'string' && !new RegExp(schema.pattern).test(value)) {
    errs.push(`${path}: "${value}" does not match /${schema.pattern}/`);
  }
  if (schema.minLength != null && typeof value === 'string' && value.length < schema.minLength) {
    errs.push(`${path}: shorter than minLength ${schema.minLength}`);
  }
  if (schema.minimum != null && typeof value === 'number' && value < schema.minimum) {
    errs.push(`${path}: below minimum ${schema.minimum}`);
  }
  if (typeOf(value) === 'array') {
    if (schema.minItems != null && value.length < schema.minItems) errs.push(`${path}: needs >= ${schema.minItems} items`);
    if (schema.items) value.forEach((v, i) => validate(v, schema.items, `${path}[${i}]`, errs));
  }
  if (typeOf(value) === 'object') {
    if (schema.minProperties != null && Object.keys(value).length < schema.minProperties) {
      errs.push(`${path}: needs >= ${schema.minProperties} properties`);
    }
    for (const req of schema.required || []) {
      if (!(req in value)) errs.push(`${path}: missing required "${req}"`);
    }
    const props = schema.properties || {};
    for (const [k, v] of Object.entries(value)) {
      if (props[k]) validate(v, props[k], `${path}.${k}`, errs);
      else if (schema.additionalProperties === false) errs.push(`${path}: unexpected property "${k}"`);
      else if (typeOf(schema.additionalProperties) === 'object') validate(v, schema.additionalProperties, `${path}.${k}`, errs);
    }
  }
}

function load(rel) {
  try { return JSON.parse(readFileSync(join(ROOT, rel), 'utf8')); }
  catch (e) { console.error(`FATAL: cannot read ${rel}: ${e.message}`); process.exit(2); }
}

function check(dataRel, schemaRel) {
  const errs = [];
  validate(load(dataRel), load(schemaRel), dataRel.split('/').pop().replace('.json', ''), errs);
  return errs;
}

const cmd = process.argv[2] || 'validate';
const reg = load('tools/farm/registry.json');
const routes = load('tools/farm/routes.json');

if (cmd === 'validate') {
  const errs = [
    ...check('tools/farm/registry.json', 'tools/farm/registry.schema.json'),
    ...check('tools/farm/routes.json', 'tools/farm/routes.schema.json'),
  ];
  // Cross-file invariants the schemas alone cannot express.
  const ids = reg.tools.map(t => t.id);
  const dupes = ids.filter((v, i) => ids.indexOf(v) !== i);
  if (dupes.length) errs.push(`registry: duplicate tool ids: ${[...new Set(dupes)].join(', ')}`);
  for (const t of reg.tools) {
    if (t.verdict === 'ADOPT' && t.verified.method !== 'ran-it-here') {
      errs.push(`registry.${t.id}: ADOPT requires verified.method="ran-it-here" (got "${t.verified.method}") — no adopting on reputation`);
    }
    if (t.verdict === 'STEAL-IDEAS-ONLY' && !t.pattern_taken) {
      errs.push(`registry.${t.id}: STEAL-IDEAS-ONLY must record pattern_taken, else it is just a bookmark`);
    }
  }
  if (!(routes.default_class in routes.classes)) errs.push(`routes: default_class "${routes.default_class}" is not a defined class`);

  if (errs.length) { console.error('FARM VALIDATION FAILED\n' + errs.map(e => '  ✗ ' + e).join('\n')); process.exit(1); }
  const n = reg.tools.length, a = reg.tools.filter(t => t.verdict === 'ADOPT').length;
  console.log(`✓ farm ok — ${n} tools (${a} adopted), ${Object.keys(routes.classes).length} route classes`);
} else if (cmd === 'list') {
  const want = process.argv[3];
  for (const t of reg.tools) {
    if (want && t.verdict !== want.toUpperCase()) continue;
    console.log(`${t.verdict.padEnd(17)} ${t.id.padEnd(34)} ${t.source}`);
  }
} else if (cmd === 'why') {
  const t = reg.tools.find(x => x.id === process.argv[3]);
  if (!t) { console.error(`no such tool: ${process.argv[3]}`); process.exit(1); }
  console.log(`${t.id}  [${t.verdict}]\n  source: ${t.source}\n  reason: ${t.reason}`);
  if (t.pattern_taken) console.log(`  pattern taken: ${t.pattern_taken}`);
  if (t.popularity_claim) console.log(`  popularity: ${t.popularity_claim}`);
  if (t.requires_secret) console.log(`  needs env var: ${t.requires_secret}`);
} else if (cmd === 'routes') {
  for (const [name, c] of Object.entries(routes.classes)) {
    console.log(`${name.padEnd(28)} ${c.tier.padEnd(7)} manifest=${c.manifest}`);
  }
} else {
  console.log('usage: farm.mjs [validate|list [VERDICT]|why <id>|routes]');
  process.exit(1);
}
