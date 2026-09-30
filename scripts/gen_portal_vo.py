#!/usr/bin/env python3
"""ElevenLabs voice for every Protocol Portal stop ASPECT (each stop has several, so a
returning player hears a new angle). Writes src/assets/portals/vo/<protocol>_<stop>_<n>.mp3.
Voices are the founder's: Pauly the Smokest (Smoke), Kane the Blaze Mechanic (Diamonds),
Rich the Miner (Gold). Skips clips that already exist unless --force.
Reads ELEVENLABS_API (founder account, has the voices) or ELEVENLABS_API_KEY from the environment (never printed)."""
import json, os, subprocess, sys, urllib.request
# Founder wants Gold on voice faxBRsvZBmi6q2wL3MQs, but neither env key can see it (voice_not_found):
# it must first be added to the account (Voice Library -> Add to My Voices). Then swap it in here and rerun with --force --only gold.
VOICES = {"smoke": "h5iQzu1FcYr7bBjBGL1i", "diamonds": "6v1vvHruJAwMrJgRpd5c", "gold": "LNV6ahDtkAOqwn1X3R7a"}
KEY = os.environ.get("ELEVENLABS_API") or os.environ["ELEVENLABS_API_KEY"]  # ELEVENLABS_API = founder account (owns the character voices)
force = "--force" in sys.argv
only = sys.argv[sys.argv.index("--only") + 1] if "--only" in sys.argv else None


def normalise(path):
    """Loudness-normalise (-14 LUFS, -1 dBTP) so every governor is equally present over the music."""
    tmp = path + ".norm.mp3"
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", path, "-af", "loudnorm=I=-14:TP=-1:LRA=9", "-b:a", "96k", tmp], check=True)
    os.replace(tmp, path)

copy = json.load(open("src/protocol_portals/data/portal_copy.json"))
os.makedirs("src/assets/portals/vo", exist_ok=True)
made = 0
for proto, data in copy.items():
    if only and proto != only:
        continue
    for stop in data.get("stops", []):
        for n, text in enumerate(stop.get("aspects", [])):
            out = f"src/assets/portals/vo/{proto}_{stop['id']}_{n}.mp3"
            if os.path.exists(out) and not force:
                continue
            req = urllib.request.Request(
                f"https://api.elevenlabs.io/v1/text-to-speech/{VOICES[proto]}?output_format=mp3_44100_64",
                data=json.dumps({"text": text, "model_id": "eleven_multilingual_v2"}).encode(),
                headers={"xi-api-key": KEY, "Content-Type": "application/json"})
            try:
                open(out, "wb").write(urllib.request.urlopen(req, timeout=90).read()); normalise(out); made += 1; print("ok", out)
            except Exception as e:
                print("FAIL", out, getattr(e, "code", type(e).__name__)); sys.exit(2)
print("new clips", made)
