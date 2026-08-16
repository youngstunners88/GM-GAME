#!/usr/bin/env python3
"""Reconstruct vault exclusive MP3s from base64 chunks committed to the repo.
Run from repo root: python3 scripts/reconstruct_vault_music.py
"""
from __future__ import annotations
import base64
import hashlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "src" / "assets" / "music"
CHUNK_ROOT = ROOT / "src" / "assets" / "music" / "_vault_music_chunks"

TRACKS = {
    "diamonds_are_forever.mp3": "diamonds_are_forever",
    "goldmine.mp3": "goldmine",
}

def reconstruct(name: str, folder: str) -> None:
    d = CHUNK_ROOT / folder
    manifest = (d / "MANIFEST.txt").read_text().strip().splitlines()
    expected = (d / "EXPECTED_MD5.txt").read_text().strip()
    b64 = "".join((d / part).read_text().strip() for part in manifest)
    data = base64.b64decode(b64)
    md5 = hashlib.md5(data).hexdigest()
    if md5 != expected:
        raise SystemExit(f"{name}: md5 mismatch {md5} != {expected}")
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    out = OUT_DIR / name
    out.write_bytes(data)
    print(f"OK {out} ({len(data)} bytes, md5={md5})")

def main() -> None:
    for name, folder in TRACKS.items():
        reconstruct(name, folder)
    print("Vault exclusive tracks ready.")

if __name__ == "__main__":
    main()
