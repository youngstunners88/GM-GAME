#!/usr/bin/env python3
"""Generate boss taunt VO from assets/boss-voices.json via ElevenLabs.
Part of the game-audio-forge skill. Outputs
src/assets/sounds/voice/boss/<boss>_<category>_<i>.mp3 — one distinct voice
per boss. ELEVENLABS_API_KEY from env only. Stdlib only.

Usage: python3 scripts/gen_boss_voices.py [--force]
"""
import json, os, sys, time, urllib.request, urllib.error
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MANIFEST = ROOT / "assets" / "boss-voices.json"
OUT = ROOT / "src" / "assets" / "sounds" / "voice" / "boss"
API = "https://api.elevenlabs.io/v1/text-to-speech"


def key():
    k = os.environ.get("ELEVENLABS_API_KEY", "")
    if not k:
        sys.exit("ELEVENLABS_API_KEY not set")
    return k


def tts(voice_id, text, model, out_path, retries=3):
    body = json.dumps({"text": text, "model_id": model}).encode()
    req = urllib.request.Request(f"{API}/{voice_id}", data=body, method="POST",
        headers={"xi-api-key": key(), "Content-Type": "application/json"})
    for attempt in range(1, retries + 1):
        try:
            with urllib.request.urlopen(req, timeout=120) as r:
                data = r.read()
            if len(data) < 800:
                print(f"  ! tiny response {len(data)}B"); continue
            out_path.parent.mkdir(parents=True, exist_ok=True)
            out_path.write_bytes(data)
            return True
        except urllib.error.HTTPError as e:
            print(f"  ! HTTP {e.code}: {e.read()[:150].decode(errors='replace')}")
            if e.code in (401, 403): return False
            time.sleep(2 * attempt)
        except Exception as e:
            print(f"  ! {e}"); time.sleep(2 * attempt)
    return False


def main():
    force = "--force" in sys.argv[1:]
    man = json.loads(MANIFEST.read_text())
    model = man.get("model_id", "eleven_multilingual_v2")
    ok = fail = skip = 0
    for boss, cfg in man["bosses"].items():
        vid = cfg["voice_id"]
        for cat, lines in cfg["lines"].items():
            for i, text in enumerate(lines):
                out = OUT / f"{boss}_{cat}_{i}.mp3"
                if out.exists() and not force:
                    skip += 1; continue
                print(f"{boss}/{cat}[{i}] \"{text}\"")
                if tts(vid, text, model, out):
                    ok += 1; print(f"  -> {out.name} ({out.stat().st_size}B)")
                else:
                    fail += 1
    print(f"\ndone: {ok} generated, {skip} skipped, {fail} failed")
    return 1 if fail else 0


if __name__ == "__main__":
    sys.exit(main())
