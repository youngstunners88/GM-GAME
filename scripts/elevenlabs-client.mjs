// Offline asset-production client. Never include credentials or this module in the game export.
//
// Uses the official SDK when it is installed; otherwise a minimal fetch client for the two calls the generators make
// (text-to-speech and sound generation), so a fresh worktree needs no npm install. Errors never include the key.

// Select the fresh session binding explicitly. Never let a legacy alias silently
// replace ELEVENLABS_API_KEY. Non-default bindings require an explicit selector.
const binding = process.env.ELEVENLABS_KEY_BINDING || 'ELEVENLABS_API_KEY';
if (!/^[A-Za-z_][A-Za-z0-9_]*$/.test(binding) || !process.env[binding]) {
  throw new Error(`Missing ElevenLabs credential binding: ${binding}`);
}
// Several keys may be set (ELEVENLABS_API_KEY, ELEVENLABS_API_KEY_2, ...). A request that is refused because a key is out of
// characters or rate-limited moves on to the next key; any other error is raised at once.
const apiKeys = [process.env[binding], ...Object.keys(process.env)
  .filter(k => /^ELEVENLABS_API_KEY_\d+$/.test(k)).sort().map(k => process.env[k]).filter(Boolean)];
const apiKey = apiKeys[0];
// Functions can have their own key: ELEVENLABS_SPEECH_API_KEY for text-to-speech (the voices), ELEVENLABS_SFX_API_KEY for sound
// effects. Each function tries its own key first, then every other key: the keys belong to different accounts, and a voice (Mike
// Dean's CfxYdK3WmF3bmrvyLAiU) or a permission may live on only one of them.
const uniq = (a) => [...new Set(a.filter(Boolean))];
const SPEECH = process.env.ELEVENLABS_SPEECH_API_KEY, SFX = process.env.ELEVENLABS_SFX_API_KEY;
const speechKeys = uniq([SPEECH, ...apiKeys, SFX]);
const sfxKeys = uniq([SFX, ...apiKeys, SPEECH]);

let Sdk = null;
try {
  ({ ElevenLabsClient: Sdk } = await import('@elevenlabs/elevenlabs-js'));
} catch {
  Sdk = null;
}

function fetchClient(key) {
  const post = async (url, body, keys = apiKeys) => {
    let last = null;
    for (const k of keys) {
      const r = await fetch(url, {
        method: 'POST',
        headers: { 'xi-api-key': k, 'Content-Type': 'application/json', Accept: 'audio/mpeg' },
        body: JSON.stringify(body),
      });
      if (r.ok) return r.body;
      const text = (await r.text()).slice(0, 300);
      last = `ElevenLabs ${r.status} on ${new URL(url).pathname}: ${text}`;
      const spent = r.status === 429 || /quota|credits|character|limit/i.test(text);
      const elsewhere = /voice_not_found|missing_permissions/i.test(text);   // that voice or function is on another account's key
      if (!spent && !elsewhere) break;         // a bad key or a bad request: no point trying the other keys
      console.warn(`ElevenLabs key ${keys.indexOf(k) + 1} of ${keys.length}: ${elsewhere ? 'this voice or function is not on that account' : 'out of characters or rate-limited'}; trying the next`);
    }
    throw new Error(last);
  };
  return {
    textToSpeech: {
      convert: (voiceId, o) => post(
        `https://api.elevenlabs.io/v1/text-to-speech/${encodeURIComponent(voiceId)}?output_format=${o.outputFormat || 'mp3_44100_128'}`,
        {
          text: o.text,
          model_id: o.modelId,
          voice_settings: o.voiceSettings
            ? { stability: o.voiceSettings.stability, similarity_boost: o.voiceSettings.similarityBoost }
            : undefined,
        },
      speechKeys),
    },
    textToSoundEffects: {
      convert: o => post('https://api.elevenlabs.io/v1/sound-generation', {
        text: o.text,
        duration_seconds: o.durationSeconds,
        loop: o.loop,
        model_id: o.modelId,
        prompt_influence: o.promptInfluence,
      }, sfxKeys),
    },
  };
}

export const elevenlabs = Sdk ? new Sdk({ apiKey }) : fetchClient(apiKey);
// The SDK path (when installed) uses the first key only; the fetch path rotates through all of them.
