/** Bounded Jev requests. Multipart encoding follows TypeSafe SDK 0.7.0 assets.ts.
 * OpenRouter currently documents JSON Decisions; image forwarding needs a real
 * acceptance/control probe. It is explicitly experimental, never a silent fallback.
 */
import { readFile } from 'node:fs/promises';
import { createHash, randomBytes } from 'node:crypto';
export const DEFAULT_MODEL = 'jev-1.14';
export const PROVIDERS = Object.freeze({typesafe:{endpoint:'https://api.typesafe.ai/v1/systemone',model:DEFAULT_MODEL},openrouter:{endpoint:'https://openrouter.ai/api/alpha/decisions',model:'typesafe/jev-1.14'}});
export const BUDGET = Object.freeze({ textBytes: 65536, longContextTextBytes: 1024 * 1024, images: 2, imageBytes: 3 * 1024 * 1024, pixels: 2100000, questions: 8 });
/** Official image limits (docs.typesafe.ai/images, read 2026-10-15). BUDGET above is stricter locally. */
export const IMAGE_LIMITS = Object.freeze({ minSide: 256, maxSide: 1568, minPixels: 78400, maxPixels: 2458624 });
/** Model pins that are 1.14-class on the native typesafe provider. `jev-latest` is 1.13, NOT 1.14. */
export const IMAGE_MODEL_PINS = Object.freeze(['jev-1.14', 'jev-1.14.0', 'jev-preview']);

function dimensions(bytes) {
  if (bytes.subarray(0, 8).equals(Buffer.from([137,80,78,71,13,10,26,10]))) {
    if (bytes.length < 24 || bytes.toString('ascii', 12, 16) !== 'IHDR') throw new Error('Malformed PNG header.');
    // Animated PNG (acTL chunk before the first IDAT) is rejected by the API.
    for (let p = 8; p + 8 <= bytes.length;) {
      const type = bytes.toString('ascii', p + 4, p + 8);
      if (type === 'acTL') throw new Error('Animated PNG is not accepted; export a still PNG or JPEG.');
      if (type === 'IDAT' || type === 'IEND') break;
      p += 12 + bytes.readUInt32BE(p);
    }
    return { mime: 'image/png', width: bytes.readUInt32BE(16), height: bytes.readUInt32BE(20) };
  }
  if (bytes[0] === 255 && bytes[1] === 216) {
    for (let p = 2; p + 8 < bytes.length;) {
      if (bytes[p++] !== 255) continue;
      let marker = bytes[p++]; while (marker === 255) marker = bytes[p++];
      if ([216,217,1].includes(marker) || (marker >= 208 && marker <= 215)) continue;
      const n = bytes.readUInt16BE(p);
      if (n < 2 || p + n > bytes.length) break;
      if ([192,193,194,195,197,198,199,201,202,203,205,206,207].includes(marker)) return { mime: 'image/jpeg', width: bytes.readUInt16BE(p + 5), height: bytes.readUInt16BE(p + 3) };
      p += n;
    }
  }
  throw new Error('Only valid PNG/JPEG image bytes are accepted; do not send base64 text as state.');
}

export async function prepareRequest({ provider = 'typesafe', model, state, questions, assets = {} }, { experimentalImages = false, longContext = false } = {}) {
  if (!Object.hasOwn(PROVIDERS,provider)) throw new Error('Provider must be typesafe or openrouter.');
  model ??= PROVIDERS[provider].model;
  if (!state || !['string','object'].includes(typeof state)) throw new Error('A nonempty state is required.');
  if (!questions || Array.isArray(questions) || typeof questions !== 'object' || !Object.keys(questions).length || Object.keys(questions).length > BUDGET.questions) throw new Error('Use 1–8 named questions per decision.');
  const wire = {};
  for (const [name, q] of Object.entries(questions)) {
    if (!q || !['boolean','noul','choice','score','box'].includes(q.type) || typeof q.instructions !== 'string' || !q.instructions.trim()) throw new Error(`Invalid question: ${name}`);
    // `box` (bounding boxes) is EXPERIMENTAL per docs: request/answer format may change; it needs image assets.
    if (q.type === 'choice' && (!q.criteria || Array.isArray(q.criteria) || typeof q.criteria !== 'object' || Object.keys(q.criteria).length < 2)) throw new Error(`Choice ${name} needs named criteria.`);
    if (q.type === 'score' && (!Array.isArray(q.criteria) || q.criteria.length < 2)) throw new Error(`Score ${name} needs ordered criteria.`);
    wire[name] = { ...q, type: q.type === 'boolean' ? 'noul' : q.type };
  }
  if (typeof model !== 'string' || !model.trim()) throw new Error('Model ID is required.');
  const payload = { model, state, questions: wire };
  const json = JSON.stringify(payload);
  if (/data:image\/[a-z0-9.+-]+;base64,/i.test(json)) throw new Error('Use binary image assets; base64 prose is not vision evidence.');
  const textLimit = longContext ? BUDGET.longContextTextBytes : BUDGET.textBytes;
  if (Buffer.byteLength(json) > textLimit) throw new Error('Local text budget exceeded: retrieve only relevant context. This budget is not the model context limit.');
  const entries = Object.entries(assets);
  if (entries.length > BUDGET.images) throw new Error('Local review budget: at most two relevant images.');
  if (entries.length && provider === 'openrouter' && !experimentalImages) throw new Error('OpenRouter image forwarding is unverified; use --experimental-images for an explicit capability probe.');
  const pins = provider === 'typesafe' ? IMAGE_MODEL_PINS : [PROVIDERS[provider].model];
  if (entries.length && !pins.includes(model)) throw new Error(`Image requests must pin a Jev 1.14 model (${pins.join(', ')}); jev-latest points at 1.13 and 1.13 ids are text-only for images.`);
  const hash = createHash('sha512').update(provider).update(json);
  const attachments = [];
  const fields = {};
  for (const [alias, filename] of entries) {
    // Two accepted spellings: SDK-style `<name>` (literal in text) and docs-style bare key `name`,
    // referenced in text as `name` inside backticks.
    const angle = /^<[A-Za-z][A-Za-z0-9_-]{0,31}>$/.test(alias);
    if (!angle && !/^[A-Za-z][A-Za-z0-9_-]{0,31}$/.test(alias)) throw new Error('Image references must be distinct <names> or bare names referenced as `name`.');
    const needle = angle ? alias : `\`${alias}\``;
    if (!JSON.stringify({state,questions:wire}).includes(needle)) throw new Error(`Unused image reference: ${alias}`);
    const bytes = await readFile(filename);
    if (bytes.length > BUDGET.imageBytes) throw new Error('Local image byte budget exceeded; crop/resize evidence first.');
    const meta = dimensions(bytes);
    const L = IMAGE_LIMITS, px = meta.width * meta.height;
    if (meta.width < L.minSide || meta.height < L.minSide) throw new Error(`Image ${alias} is ${meta.width}x${meta.height}: each side must be at least ${L.minSide}px; resize/upscale or crop a larger region.`);
    if (meta.width > L.maxSide || meta.height > L.maxSide) throw new Error(`Image ${alias} is ${meta.width}x${meta.height}: each side must be at most ${L.maxSide}px; resize or crop it.`);
    if (px < L.minPixels || px > L.maxPixels) throw new Error(`Image ${alias} has ${px} pixels: total must be ${L.minPixels}..${L.maxPixels}; resize or crop it.`);
    if (px > BUDGET.pixels) throw new Error('Local image pixel budget exceeded; resize or crop evidence first.');
    const part = `asset-${attachments.length}`;
    fields[alias] = { type: 'image', part };
    hash.update(alias).update(bytes);
    attachments.push({ part, bytes, ...meta });
  }
  let body = json;
  const headers = { 'Content-Type': 'application/json' };
  if (attachments.length) {
    // Match the official SDK exactly: the JSON request part has NO filename.
    // FormData + Blob would add filename="blob", which servers can parse as an
    // uploaded file instead of the required JSON request field.
    const boundary = `jev-${randomBytes(16).toString('hex')}`;
    const chunks = [
      `--${boundary}\r\nContent-Disposition: form-data; name="request"\r\nContent-Type: application/json\r\n\r\n`,
      JSON.stringify({...payload,assets:fields}), '\r\n',
    ];
    for (const a of attachments) chunks.push(
      `--${boundary}\r\nContent-Disposition: form-data; name="${a.part}"; filename="${a.part}"\r\nContent-Type: ${a.mime}\r\n\r\n`,
      a.bytes, '\r\n',
    );
    chunks.push(`--${boundary}--\r\n`);
    body = new Blob(chunks);
    headers['Content-Type'] = `multipart/form-data; boundary=${boundary}`;
    headers['TypeSafe-Danger-Zone-Images'] = 'true';
  }
  if (longContext) headers['TypeSafe-Danger-Zone-Long-Context'] = 'true'; // raises server limits 64k->262k; opt-in only
  return { body, headers, summary: { provider, model, longContext, questionNames: Object.keys(wire), textBytes: Buffer.byteLength(json), images: attachments.map(({width,height,mime,bytes})=>({width,height,mime,bytes:bytes.length})), digest:hash.digest('hex'), imageTransport: provider === 'typesafe' ? 'documented TypeSafe multipart; live probe pending' : 'upstream SDK multipart; OpenRouter acceptance unverified' } };
}

export function validateResponse(data, questions) {
  if (!data || !data.answers || typeof data.model !== 'string') throw new Error('Malformed Jev response: missing model/answers.');
  for (const [name,q] of Object.entries(questions)) {
    const a=data.answers[name]; const type=q.type==='boolean'?'noul':q.type;
    if (!a || a.type!==type) throw new Error(`Malformed answer: ${name}`);
    if (type==='box') continue; // experimental: shape not validated, only the type
    if (type==='noul' && (!Number.isFinite(a.noul) || a.noul<0 || a.noul>1)) throw new Error(`Invalid probability: ${name}`);
    if (type==='choice' && !Object.hasOwn(q.criteria,a.choice)) throw new Error(`Unknown choice: ${name}`);
    if (type==='score' && (!Number.isFinite(a.score) || a.score<0 || a.score>q.criteria.length-1)) throw new Error(`Invalid score: ${name}`);
  }
  return data;
}
