#!/usr/bin/env python3
"""ElevenLabs barks for the Protocol Portals tour stops (Qwen FACT_LOCK: PASS copy only).
Reads ELEVENLABS_API_KEY from the environment (never printed). Writes
src/assets/portals/vo/<protocol>_<stop_id>.mp3 for the pillar stops only."""
import json, os, sys, urllib.request
VOICE = "N2lVS1w4EtoT3dr4eOWO"  # game announcer (Callum), assets/audio-manifest.json
SKIP = {"paper", "video", "exam"}
copy = json.load(open("src/protocol_portals/data/portal_copy.json"))
os.makedirs("src/assets/portals/vo", exist_ok=True)
ok = 0
for proto, data in copy.items():
    for stop in [s for s in data.get("stops", []) if s.get("id") not in SKIP][:5]:
        out = f"src/assets/portals/vo/{proto}_{stop['id']}.mp3"
        req = urllib.request.Request(f"https://api.elevenlabs.io/v1/text-to-speech/{VOICE}?output_format=mp3_44100_64",
            data=json.dumps({"text": stop["line"], "model_id": "eleven_multilingual_v2"}).encode(),
            headers={"xi-api-key": os.environ["ELEVENLABS_API_KEY"], "Content-Type": "application/json"})
        try:
            open(out, "wb").write(urllib.request.urlopen(req, timeout=60).read()); ok += 1; print("ok", out)
        except Exception as e:
            print("FAIL", out, getattr(e, "code", type(e).__name__)); sys.exit(2)
print("clips", ok)
