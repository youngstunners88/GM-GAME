#!/usr/bin/env python3
"""ElevenLabs audio for the NFT congratulations: two short jingles (boss / test) and one spoken
Lil Blunt line per NFT. Writes src/assets/nft/audio/*.mp3. Skips existing unless --force.
Lines and ids come from src/data/nft_collection.json (single source). Key is read from the environment, never printed."""
import json, os, subprocess, sys, urllib.request
KEY = os.environ.get("ELEVENLABS_API") or os.environ["ELEVENLABS_API_KEY"]
LIL_BLUNT = "HMGfKwZCRujgXyRDUW0b"
force = "--force" in sys.argv
OUT = "src/assets/nft/audio"
os.makedirs(OUT, exist_ok=True)
JINGLES = {
    "jingle_boss": "short cool chill victory jingle, bouncy 8-bit retro chiptune with a warm synth chord at the end, playful and triumphant, no vocals, 2 seconds",
    "jingle_test": "short cool chill achievement jingle, twinkly retro chiptune arpeggio rising to a bright finish, smart and cheerful, no vocals, 2 seconds",
}

def norm(path, tail=None):
    tmp = path + ".n.mp3"
    af = "loudnorm=I=-14:TP=-1:LRA=9"
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", path, "-af", af, "-ac", "1", "-b:a", "64k", tmp], check=True)
    os.replace(tmp, path)

def post(url, body, out):
    req = urllib.request.Request(url, data=json.dumps(body).encode(), headers={"xi-api-key": KEY, "Content-Type": "application/json"})
    open(out, "wb").write(urllib.request.urlopen(req, timeout=120).read()); norm(out); print("ok", out)

for name, prompt in JINGLES.items():
    out = f"{OUT}/{name}.mp3"
    if force or not os.path.exists(out):
        post("https://api.elevenlabs.io/v1/sound-generation", {"text": prompt, "duration_seconds": 2.2, "prompt_influence": 0.5}, out)
for nft in json.load(open("src/data/nft_collection.json"))["nfts"]:
    out = f"{OUT}/{nft['id']}_voice.mp3"
    if force or not os.path.exists(out):
        post(f"https://api.elevenlabs.io/v1/text-to-speech/{LIL_BLUNT}?output_format=mp3_44100_64",
             {"text": nft["spoken"], "model_id": "eleven_multilingual_v2"}, out)
