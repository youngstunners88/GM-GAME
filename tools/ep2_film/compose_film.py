#!/usr/bin/env python3
"""Compose the Episode 2 transition film (skill ep2-seedance-film): concat the Seedance clips, DROP their own audio,
lay dialogue + foley on a timeline (NO MUSIC, ever) and encode Ogg Theora/Vorbis for Godot 4.3 web.

  python3 tools/ep2_film/compose_film.py            # -> src/assets/video/cutscenes/ep2_cliff_to_hideout.ogv
  python3 tools/ep2_film/compose_film.py --check    # prints the timeline only

Timeline entries are (file, global start seconds, gain). Clip starts: S1 0, S2 5, S3 10, S4 15, S5 25 (see film.json durations).
"""
import json, subprocess, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FILM = ROOT / ".farm/film"
VOICE = ROOT / "tools/ep2_film/voice"      # film_* lines live OUTSIDE src/: they are baked into the .ogv, shipping them too costs pck MB
GAME_VOICE = ROOT / "src/assets/sounds/voice"
SND = ROOT / "src/assets/sounds"
OUT = ROOT / "src/assets/video/cutscenes/ep2_cliff_to_hideout.ogv"
MIX = FILM / "film_mix.wav"
JOIN = FILM / "film_picture.mp4"

CLIPS = ["S1_exit", "S2_fly", "S3_wound", "S4_give", "S5_teach"]
TIMELINE = json.loads((ROOT / "tools/ep2_film/timeline.json").read_text())


def dur(p):
    return float(subprocess.check_output(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", str(p)]).decode().strip())


def main():
    entries = []
    for e in TIMELINE["audio"]:
        base = VOICE if e["file"].startswith("film_") else GAME_VOICE if e["file"].startswith("vo_") else SND
        f = base / (e["file"] + ".mp3")
        entries.append((f, float(e["at"]), float(e.get("gain", 1.0)), e.get("fade_out"), e.get("trim")))
    for f, at, g, _, _ in entries:
        print(f"{at:6.2f}s  x{g:.2f}  {f.name}  ({dur(f):.2f}s)")
    if "--check" in sys.argv:
        return
    # picture: concat the four clips (video only; the Seedance audio is discarded on purpose)
    lst = FILM / "concat.txt"
    lst.write_text("".join(f"file '{FILM / (c + '.mp4')}'\n" for c in CLIPS))
    subprocess.check_call(["ffmpeg", "-v", "error", "-y", "-f", "concat", "-safe", "0", "-i", str(lst), "-an", "-r", "24",
                           "-c:v", "libx264", "-crf", "16", "-preset", "fast", str(JOIN)])
    total = dur(JOIN)
    # sound: every cue delayed to its timestamp, mixed, no music
    args, flt, labels = [], [], []
    for i, (f, at, g, fo, trim) in enumerate(entries):
        args += ["-i", str(f)]
        chain = f"[{i}:a]aformat=sample_rates=44100:channel_layouts=stereo"
        if trim:
            chain += f",atrim=0:{trim}"
        if fo:
            d = trim if trim else dur(f)
            chain += f",afade=t=out:st={max(0.0, d - fo):.2f}:d={fo}"
        chain += f",volume={g},adelay={int(at * 1000)}|{int(at * 1000)}[a{i}]"
        flt.append(chain)
        labels.append(f"[a{i}]")
    flt.append("".join(labels) + f"amix=inputs={len(entries)}:normalize=0,alimiter=limit=0.95,loudnorm=I=-14:TP=-1.5:LRA=11,apad=whole_dur={total:.2f},atrim=0:{total:.2f}[m]")
    subprocess.check_call(["ffmpeg", "-v", "error", "-y", *args, "-filter_complex", ";".join(flt), "-map", "[m]", "-ar", "44100", str(MIX)])
    OUT.parent.mkdir(parents=True, exist_ok=True)
    subprocess.check_call(["ffmpeg", "-v", "error", "-y", "-i", str(JOIN), "-i", str(MIX), "-map", "0:v", "-map", "1:a",
                           "-vf", "scale=1024:576", "-c:v", "libtheora", "-q:v", str(TIMELINE.get("theora_q", 2)), "-r", "24",
                           "-c:a", "libvorbis", "-q:a", "2", str(OUT)])
    print(f"wrote {OUT.relative_to(ROOT)}  {OUT.stat().st_size / 1e6:.1f} MB  {total:.1f}s")


if __name__ == "__main__":
    main()
