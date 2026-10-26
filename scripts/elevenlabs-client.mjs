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
const apiKey = process.env[binding];

let Sdk = null;
try {
  ({ ElevenLabsClient: Sdk } = await import('@elevenlabs/elevenlabs-js'));
} catch {
  Sdk = null;
}

function fetchClient(key) {
  const post = async (url, body) => {
    const r = await fetch(url, {
      method: 'POST',
      headers: { 'xi-api-key': key, 'Content-Type': 'application/json', Accept: 'audio/mpeg' },
      body: JSON.stringify(body),
    });
    if (!r.ok) throw new Error(`ElevenLabs ${r.status} on ${new URL(url).pathname}: ${(await r.text()).slice(0, 300)}`);
    return r.body;
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
      ),
    },
    textToSoundEffects: {
      convert: o => post('https://api.elevenlabs.io/v1/sound-generation', {
        text: o.text,
        duration_seconds: o.durationSeconds,
        loop: o.loop,
        model_id: o.modelId,
        prompt_influence: o.promptInfluence,
      }),
    },
  };
}

export const elevenlabs = Sdk ? new Sdk({ apiKey }) : fetchClient(apiKey);
