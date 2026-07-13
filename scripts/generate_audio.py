#!/usr/bin/env python3
"""Generate all game SFX + voiceovers from assets/audio-manifest.json via
the ElevenLabs API. Part of the game-audio-forge skill
(.claude/skills/game-audio-forge/SKILL.md — prompt-engineering rules live there).

Usage:
  python3 scripts/generate_audio.py              generate everything missing
  python3 scripts/generate_audio.py --dry-run    list what would be generated
  python3 scripts/generate_audio.py --force id…  regenerate specific ids
  python3 scripts/generate_audio.py --force-all  regenerate everything

Auth: ELEVENLABS_API_KEY env var only — never hardcoded (SEC-001).
Stdlib only; no pip deps. Writes MP3 (Godot 4.3 plays it natively;
AudioManager resolves .ogg first, then .mp3).
"""

import json
import os
import sys
import time
import urllib.request
import urllib.error
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MANIFEST = ROOT / "assets" / "audio-manifest.json"
SFX_DIR = ROOT / "src" / "assets" / "sounds"
VOICE_DIR = SFX_DIR / "voice"

API = "https://api.elevenlabs.io/v1"


def api_key() -> str:
    key = os.environ.get("ELEVENLABS_API_KEY", "")
    if not key:
        sys.exit("ELEVENLABS_API_KEY not set in environment")
    return key


def post(url: str, payload: dict, out_path: Path, retries: int = 3) -> bool:
    body = json.dumps(payload).encode()
    req = urllib.request.Request(url, data=body, method="POST", headers={
        "xi-api-key": api_key(),
        "Content-Type": "application/json",
    })
    for attempt in range(1, retries + 1):
        try:
            with urllib.request.urlopen(req, timeout=120) as resp:
                data = resp.read()
            if len(data) < 1000:
                print(f"  ! suspiciously small response ({len(data)}B), attempt {attempt}")
                continue
            out_path.parent.mkdir(parents=True, exist_ok=True)
            out_path.write_bytes(data)
            return True
        except urllib.error.HTTPError as e:
            detail = e.read()[:300].decode(errors="replace")
            print(f"  ! HTTP {e.code} (attempt {attempt}): {detail}")
            if e.code in (401, 403):
                return False  # auth issues won't fix themselves — don't retry
            time.sleep(2 * attempt)
        except Exception as e:  # network hiccups: retry
            print(f"  ! {e} (attempt {attempt})")
            time.sleep(2 * attempt)
    return False


def main() -> int:
    args = sys.argv[1:]
    dry = "--dry-run" in args
    force_all = "--force-all" in args
    force_ids = set()
    if "--force" in args:
        force_ids = {a for a in args[args.index("--force") + 1:] if not a.startswith("--")}

    manifest = json.loads(MANIFEST.read_text())
    voice_id = manifest["voice_id"]
    ok = fail = skip = 0

    for sfx in manifest.get("sfx", []):
        out = SFX_DIR / f"{sfx['id']}.mp3"
        # Legacy .ogg for the same id counts as present (e.g. fresh_boost).
        if not force_all and sfx["id"] not in force_ids and (
                out.exists() or (SFX_DIR / f"{sfx['id']}.ogg").exists()):
            skip += 1
            continue
        print(f"SFX  {sfx['id']}  ({sfx['duration_seconds']}s)")
        if dry:
            continue
        if post(f"{API}/sound-generation", {
            "text": sfx["prompt"],
            "duration_seconds": sfx["duration_seconds"],
            "prompt_influence": sfx.get("prompt_influence", 0.4),
        }, out):
            ok += 1
            print(f"  -> {out.relative_to(ROOT)} ({out.stat().st_size}B)")
        else:
            fail += 1

    for line in manifest.get("voice", []):
        out = VOICE_DIR / f"{line['id']}.mp3"
        if not force_all and line["id"] not in force_ids and out.exists():
            skip += 1
            continue
        print(f"VO   {line['id']}  \"{line['text']}\"")
        if dry:
            continue
        if post(f"{API}/text-to-speech/{voice_id}", {
            "text": line["text"],
            "model_id": "eleven_multilingual_v2",
        }, out):
            ok += 1
            print(f"  -> {out.relative_to(ROOT)} ({out.stat().st_size}B)")
        else:
            fail += 1

    print(f"\ndone: {ok} generated, {skip} already present, {fail} failed")
    return 1 if fail else 0


if __name__ == "__main__":
    sys.exit(main())
