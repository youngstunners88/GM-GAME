/** Bounded Jev requests. Multipart encoding follows TypeSafe SDK 0.7.0 assets.ts.
 * OpenRouter currently documents JSON Decisions; image forwarding needs a real
 * acceptance/control probe. It is explicitly experimental, never a silent fallback.
 */
import { readFile } from 'node:fs/promises';
import { createHash, randomBytes } from 'node:crypto';
export const DEFAULT_MODEL = 'jev-1.14';
export const PROVIDERS = Object.freeze({typesafe:{endpoint:'https://api.typesafe.ai/v1/systemone',model:DEFAULT_MODEL},openrouter:{endpoint:'https://openrouter.ai/api/alpha/decisions',model:'typesafe/jev-1.14'}});
export const BUDGET = Object.freeze({ textBytes: 65536, images: 2, imageBytes: 3 * 1024 * 1024, pixels: 2100000, questions: 8 });

function dimensions(bytes) {
  if (bytes.subarray(0, 8).equals(Buffer.from([137,80,78,71,13,10,26,10]))) {
    if (bytes.length < 24 || bytes.toString('ascii', 12, 16) !== 'IHDR') throw new Error('Malformed PNG header.');
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

export async function prepareRequest({ provider = 'typesafe', model, state, questions, assets = {} }, { experimentalImages = false } = {}) {
  if (!Object.hasOwn(PROVIDERS,provider)) throw new Error('Provider must be typesafe or openrouter.');
  model ??= PROVIDERS[provider].model;
  if (!state || !['string','object'].includes(typeof state)) throw new Error('A nonempty state is required.');
  if (!questions || Array.isArray(questions) || typeof questions !== 'object' || !Object.keys(questions).length || Object.keys(questions).length > BUDGET.questions) throw new Error('Use 1–8 named questions per decision.');
  const wire = {};
  for (const [name, q] of Object.entries(questions)) {
    if (!q || !['boolean','noul','choice','score'].includes(q.type) || typeof q.instructions !== 'string' || !q.instructions.trim()) throw new Error(`Invalid question: ${name}`);
    if (q.type === 'choice' && (!q.criteria || Array.isArray(q.criteria) || typeof q.criteria !== 'object' || Object.keys(q.criteria).length < 2)) throw new Error(`Choice ${name} needs named criteria.`);
    if (q.type === 'score' && (!Array.isArray(q.criteria) || q.criteria.length < 2)) throw new Error(`Score ${name} needs ordered criteria.`);
    wire[name] = { ...q, type: q.type === 'boolean' ? 'noul' : q.type };
  }
  if (typeof model !== 'string' || !model.trim()) throw new Error('Model ID is required.');
  const payload = { model, state, questions: wire };
  const json = JSON.stringify(payload);
  if (/data:image\/[a-z0-9.+-]+;base64,/i.test(json)) throw new Error('Use binary image assets; base64 prose is not vision evidence.');
  if (Buffer.byteLength(json) > BUDGET.textBytes) throw new Error('Local text budget exceeded: retrieve only relevant context. This budget is not the model context limit.');
  const entries = Object.entries(assets);
  if (entries.length > BUDGET.images) throw new Error('Local review budget: at most two relevant images.');
  if (entries.length && provider === 'openrouter' && !experimentalImages) throw new Error('OpenRouter image forwarding is unverified; use --experimental-images for an explicit capability probe.');
  if (entries.length && model !== PROVIDERS[provider].model) throw new Error('Image requests pin Jev 1.14 for the selected provider; never send images to an older/text-only alias.');
  const hash = createHash('sha512').update(provider).update(json);
  const attachments = [];
  const fields = {};
  for (const [alias, filename] of entries) {
    if (!/^<[A-Za-z][A-Za-z0-9_-]{0,31}>$/.test(alias)) throw new Error('Image references must be distinct <names>.');
    if (!JSON.stringify({state,questions:wire}).includes(alias)) throw new Error(`Unused image reference: ${alias}`);
    const bytes = await readFile(filename);
    if (bytes.length > BUDGET.imageBytes) throw new Error('Local image byte budget exceeded; crop/resize evidence first.');
    const meta = dimensions(bytes);
    if (!meta.width || !meta.height || meta.width * meta.height > BUDGET.pixels) throw new Error('Local image pixel budget exceeded.');
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
  return { body, headers, summary: { provider, model, questionNames: Object.keys(wire), textBytes: Buffer.byteLength(json), images: attachments.map(({width,height,mime,bytes})=>({width,height,mime,bytes:bytes.length})), digest:hash.digest('hex'), imageTransport: provider === 'typesafe' ? 'documented TypeSafe multipart; live probe pending' : 'upstream SDK multipart; OpenRouter acceptance unverified' } };
}

export function validateResponse(data, questions) {
  if (!data || !data.answers || typeof data.model !== 'string') throw new Error('Malformed Jev response: missing model/answers.');
  for (const [name,q] of Object.entries(questions)) {
    const a=data.answers[name]; const type=q.type==='boolean'?'noul':q.type;
    if (!a || a.type!==type) throw new Error(`Malformed answer: ${name}`);
    if (type==='noul' && (!Number.isFinite(a.noul) || a.noul<0 || a.noul>1)) throw new Error(`Invalid probability: ${name}`);
    if (type==='choice' && !Object.hasOwn(q.criteria,a.choice)) throw new Error(`Unknown choice: ${name}`);
    if (type==='score' && (!Number.isFinite(a.score) || a.score<0 || a.score>q.criteria.length-1)) throw new Error(`Invalid score: ${name}`);
  }
  return data;
}
