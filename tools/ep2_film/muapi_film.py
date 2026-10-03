#!/usr/bin/env python3
"""Muapi helpers for the Episode 2 film (skill ep2-seedance-film). Key: MUAPI_API_KEY from the environment only.

  python3 tools/ep2_film/muapi_film.py balance
  python3 tools/ep2_film/muapi_film.py upload  img.png                       -> prints the CDN url
  python3 tools/ep2_film/muapi_film.py edit    out.png "prompt" url1 [url2..] [--aspect 16:9] [--res 2k]   (nano-banana-pro-edit)
  python3 tools/ep2_film/muapi_film.py i2v     out.mp4 "prompt" url1 [url2..] [--dur 10] [--res 720p] [--quality basic]  (seedance-v2.0-i2v)
  python3 tools/ep2_film/muapi_film.py shot    shotname                       (runs one shot from tools/ep2_film/film.json)

Every job prints the request id and the balance delta (so the cost of a take is on the record). Seedance clips are
saved WITHOUT relying on their audio: the film's soundtrack is composed by compose_film.sh (dialogue + foley, no music).
"""
import json, os, sys, time, urllib.request, urllib.error, subprocess, uuid
from pathlib import Path

BASE = "https://api.muapi.ai/api/v1"
ROOT = Path(__file__).resolve().parents[2]


def key():
    k = os.environ.get("MUAPI_API_KEY", "")
    if not k:
        sys.exit("MUAPI_API_KEY not set")
    return k


def call(path, payload=None, method="GET"):
    data = json.dumps(payload).encode() if payload is not None else None
    r = urllib.request.Request(BASE + path, data=data, method=method, headers={"x-api-key": key(), "Content-Type": "application/json"})
    with urllib.request.urlopen(r, timeout=120) as resp:
        return json.loads(resp.read())


def balance():
    return float(call("/account/balance")["balance"])


def upload(path):
    boundary = uuid.uuid4().hex
    b = Path(path).read_bytes()
    body = (f"--{boundary}\r\nContent-Disposition: form-data; name=\"file\"; filename=\"{Path(path).name}\"\r\n"
            f"Content-Type: application/octet-stream\r\n\r\n").encode() + b + f"\r\n--{boundary}--\r\n".encode()
    r = urllib.request.Request(BASE + "/upload_file", data=body, method="POST",
                               headers={"x-api-key": key(), "Content-Type": f"multipart/form-data; boundary={boundary}"})
    with urllib.request.urlopen(r, timeout=300) as resp:
        return json.loads(resp.read())["url"]


def run(endpoint, payload, out, tries=240, every=5):
    b0 = balance()
    sub = call("/" + endpoint, payload, "POST")
    rid = sub.get("request_id") or sub.get("id")
    print("submitted", endpoint, rid, flush=True)
    if not rid:
        sys.exit(f"no request id: {sub}")
    for _ in range(tries):
        time.sleep(every)
        try:
            res = call(f"/predictions/{rid}/result")
        except urllib.error.HTTPError as e:
            if e.code == 404:
                continue
            raise
        st = res.get("status")
        if st == "completed":
            url = (res.get("outputs") or [None])[0]
            urllib.request.urlretrieve(url, out)
            print(f"done {out}  request_id={rid}  cost=${b0 - balance():.3f}  balance=${balance():.3f}")
            Path(str(out) + ".json").write_text(json.dumps({"request_id": rid, "endpoint": endpoint, "payload": payload, "url": url}, indent=1))
            return rid
        if st in ("failed", "cancelled"):
            sys.exit(f"{st}: {res.get('error')}")
    sys.exit("timed out")


def main(a):
    if not a:
        sys.exit(__doc__)
    c = a[0]
    opts = {}
    rest = []
    i = 1
    while i < len(a):
        if a[i].startswith("--"):
            opts[a[i][2:]] = a[i + 1]; i += 2
        else:
            rest.append(a[i]); i += 1
    if c == "balance":
        print(f"${balance():.3f}")
    elif c == "upload":
        print(upload(rest[0]))
    elif c == "edit":
        run("nano-banana-pro-edit", {"prompt": rest[1], "images_list": rest[2:], "aspect_ratio": opts.get("aspect", "16:9"),
                                      "resolution": opts.get("res", "2k")}, rest[0])
    elif c == "i2v":
        run("seedance-v2.0-i2v", {"prompt": rest[1], "images_list": rest[2:], "aspect_ratio": opts.get("aspect", "16:9"),
                                   "duration": int(opts.get("dur", 10)), "resolution": opts.get("res", "720p"),
                                   "quality": opts.get("quality", "basic")}, rest[0])
    elif c == "shot":
        film = json.loads((ROOT / "tools/ep2_film/film.json").read_text())
        s = next(x for x in film["shots"] if x["id"] == rest[0])
        urls = [upload(ROOT / p) if not p.startswith("http") else p for p in s["images"]]
        out = ROOT / f".farm/film/{s['id']}.mp4"
        run("seedance-v2.0-i2v", {"prompt": film["style"] + " " + s["prompt"], "images_list": urls, "aspect_ratio": "16:9",
                                  "duration": s["duration"], "resolution": film.get("resolution", "720p"),
                                  "quality": film.get("quality", "basic")}, out)
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main(sys.argv[1:])
