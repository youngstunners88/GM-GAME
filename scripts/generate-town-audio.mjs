// Generate only the requested town cast and effects, then emit the game's resource bank.
// node scripts/generate-town-audio.mjs --plan
// node scripts/generate-town-audio.mjs --generate [--speakers rich,lil_blunt] [--sfx]
import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { spawnSync } from 'node:child_process';

const config = JSON.parse(await readFile('assets/town-audio.json', 'utf8'));
const args = process.argv.slice(2);
const option = k => args.includes(k) ? args[args.indexOf(k) + 1] : '';
const speakers = new Set((option('--speakers') || Object.keys(config.voices).join(',')).split(','));
const work = 'work/town-voices/recordings';
const out = 'src/episode2/extras/audio/town';
await mkdir(work, { recursive: true });
await mkdir(out, { recursive: true });
const receiptPath = 'assets/town-audio-generated.json';
const receipts = existsSync(receiptPath) ? JSON.parse(await readFile(receiptPath, 'utf8')) : {};
const hash = x => createHash('sha256').update(JSON.stringify(x)).digest('hex');
const processingVersion = 2;
const candidates = config.lines.filter(r => speakers.has(r.speaker));
console.log(JSON.stringify({ lines: candidates.length, characters: candidates.reduce((n, r) => n + r.text.length, 0), pendingVoices: [...speakers].filter(k => !config.voices[k]?.voice_id), sfx: args.includes('--sfx') ? config.sfx.length : 0 }));

function run(command, argv) {
  const r = spawnSync(command, argv, { encoding: 'utf8' });
  if (r.status !== 0) throw new Error(`${command} failed: ${r.stderr?.slice(-400)}`);
  return r.stdout;
}
async function save(id, audio, source, effect = false) {
  const raw = `${work}/${id}.mp3`;
  if (audio) await writeFile(raw, Buffer.from(await new Response(audio).arrayBuffer()));
  await writeFile(`${raw}.source.json`, JSON.stringify(source));
  // Keep the complete ambience loop. Normalize quiet foley before any onset trim.
  const filters = effect
    ? (source.loop ? 'highpass=f=70,loudnorm=I=-19:TP=-4:LRA=9,alimiter=limit=0.65:level=false:latency=true' : 'highpass=f=70,loudnorm=I=-19:TP=-4:LRA=9,silenceremove=start_periods=1:start_duration=0.001:start_threshold=-35dB,alimiter=limit=0.65:level=false:latency=true')
    : 'silenceremove=start_periods=1:start_duration=0.015:start_threshold=-45dB,loudnorm=I=-20:TP=-4:LRA=9,alimiter=limit=0.65:level=false:latency=true';
  run('ffmpeg', ['-y', '-v', 'error', '-i', raw, '-af', filters, '-ac', '1', '-ar', effect ? '44100' : '24000', '-c:a', 'libvorbis', '-q:a', effect ? '3' : '2', `${out}/${id}.ogg`]);
  const duration = Number(run('ffprobe', ['-v', 'error', '-show_entries', 'format=duration', '-of', 'default=nw=1:nk=1', `${out}/${id}.ogg`]).trim());
  const probe = JSON.parse(run('ffprobe', ['-v', 'error', '-show_entries', 'stream=start_time', '-of', 'json', `${out}/${id}.ogg`]));
  const startSeconds = Number(probe.streams[0].start_time || 0);
  const bytes = await readFile(`${out}/${id}.ogg`);
  receipts[id] = { source_hash: hash(source), processing_version: processingVersion, sha256: createHash('sha256').update(bytes).digest('hex'), bytes: bytes.length, ...source, seconds: duration, start_seconds: startSeconds };
  await writeFile(receiptPath, JSON.stringify(receipts, null, 2) + '\n');
  console.log(`${id}: ${duration.toFixed(2)}s, ${bytes.length}B`);
}

if (args.includes('--generate')) {
  const { elevenlabs } = await import('./elevenlabs-client.mjs');
  for (const row of candidates) {
    const voice = config.voices[row.speaker];
    if (!voice?.voice_id) { console.log(`PENDING voice slot: ${row.id}`); continue; }
    // A voice may carry its own model and settings (Inferno keeps the model and delivery of his Episode 2 lines); the rest use the
    // manifest's model and the house settings, so their source hashes - and recordings - are unchanged.
    const model = voice.model_id || config.model_id;
    const vs = voice.voice_settings || {};
    const source = { text: row.text, speaker: row.speaker, voice_id: voice.voice_id, model_id: model };
    if (receipts[row.id]?.source_hash === hash(source)) {
      if (receipts[row.id]?.processing_version === processingVersion && existsSync(`${out}/${row.id}.ogg`)) continue;
      if (existsSync(`${work}/${row.id}.mp3`)) { await save(row.id, null, source); continue; }
    }
    const audio = await elevenlabs.textToSpeech.convert(voice.voice_id, { text: row.text, modelId: model, outputFormat: 'mp3_44100_128',
      voiceSettings: { stability: vs.stability ?? 0.55, similarityBoost: vs.similarity_boost ?? 0.8, style: vs.style, speed: vs.speed } });
    await save(row.id, audio, source);
  }
  if (args.includes('--sfx')) for (const row of config.sfx) {
    const source = { prompt: row.prompt, seconds: row.seconds, loop: row.loop, model_id: 'eleven_text_to_sound_v2' };
    if (receipts[row.id]?.source_hash === hash(source) && receipts[row.id]?.processing_version === processingVersion && existsSync(`${out}/${row.id}.ogg`)) continue;
    const raw = `${work}/${row.id}.mp3`;
    if (existsSync(`${raw}.source.json`) && hash(JSON.parse(await readFile(`${raw}.source.json`, 'utf8'))) === hash(source)) {
      await save(row.id, null, source, true);
      continue;
    }
    const audio = await elevenlabs.textToSoundEffects.convert({ text: row.prompt, durationSeconds: row.seconds, loop: row.loop, modelId: 'eleven_text_to_sound_v2', promptInfluence: 0.6 });
    await save(row.id, audio, source, true);
  }
}

const rows = Object.fromEntries(config.lines.map(r => {
  const expected = { text: r.text, speaker: r.speaker, voice_id: config.voices[r.speaker]?.voice_id, model_id: config.voices[r.speaker]?.model_id || config.model_id };
  const ready = receipts[r.id]?.source_hash === hash(expected) && existsSync(`${out}/${r.id}.ogg`);
  return [r.id, { speaker: r.speaker, text: r.text, seconds: ready ? receipts[r.id].seconds : 0, start_seconds: ready ? (receipts[r.id].start_seconds || 0) : 0, ready, path: `res://${out}/${r.id}.ogg` }];
}));
const gd = `class_name Ep2TownVoiceBank\nextends RefCounted\n## Generated by scripts/generate-town-audio.mjs; source assets/town-audio.json.\nconst LINES: Dictionary = ${JSON.stringify(rows, null, '\t')}\nconst GREETINGS: Dictionary = ${JSON.stringify(config.greetings, null, '\t')}\n\nstatic func id_for(speaker: String, text: String) -> String:\n\tfor id in LINES:\n\t\tif LINES[id]["speaker"] == speaker and LINES[id]["text"] == text:\n\t\t\treturn str(id)\n\treturn ""\n\nstatic func seconds(id: String, fallback: float = 4.2) -> float:\n\t# Sequence speech using the engine stream duration; receipt seconds audit the encoded file.\n\tvar recording: AudioStream = stream(id)\n\treturn recording.get_length() + 0.25 if recording != null else fallback\n\nstatic func stream(id: String) -> AudioStream:\n\tif not LINES.has(id) or not LINES[id]["ready"]:\n\t\treturn null\n\tvar path: String = LINES[id]["path"]\n\treturn load(path) as AudioStream if ResourceLoader.exists(path) else null\n`;
await mkdir('src/episode2/audio', { recursive: true });
await writeFile('src/episode2/audio/town_voice_bank.gd', gd);
