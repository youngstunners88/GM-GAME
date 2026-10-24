// Offline asset-production client. Never include credentials or this module in the game export.
import { ElevenLabsClient } from '@elevenlabs/elevenlabs-js';

// Honor the project's established workspace binding when it exists. The SDK reads
// its normal environment variable; no credential is stored in code or browser files.
if (process.env.ELEVENLABS_API) process.env.ELEVENLABS_API_KEY = process.env.ELEVENLABS_API;
export const elevenlabs = new ElevenLabsClient();
