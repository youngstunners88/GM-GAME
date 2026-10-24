// Offline asset-production client. Never include credentials or this module in the game export.
import { ElevenLabsClient } from '@elevenlabs/elevenlabs-js';

// Select the fresh session binding explicitly. Never let a legacy alias silently
// replace ELEVENLABS_API_KEY. Non-default bindings require an explicit selector.
const binding = process.env.ELEVENLABS_KEY_BINDING || 'ELEVENLABS_API_KEY';
if (!/^[A-Za-z_][A-Za-z0-9_]*$/.test(binding) || !process.env[binding]) {
  throw new Error(`Missing ElevenLabs credential binding: ${binding}`);
}
export const elevenlabs = new ElevenLabsClient({ apiKey: process.env[binding] });
