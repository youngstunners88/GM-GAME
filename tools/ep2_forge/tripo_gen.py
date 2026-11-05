#!/usr/bin/env python3
"""Native Tripo v3 generation (founder's own credits; pay-per-call Tripo through Muapi is tools/ep2_forge/muapi_3d.py).
The key comes from the environment and is never printed: set -a; . /home/kofibeatz/GM-GAME/.env; set +a

  python3 tools/ep2_forge/tripo_gen.py balance
  python3 tools/ep2_forge/tripo_gen.py image <ref.jpg> --out .farm/tripo/<name> [--set k=v ...]
  python3 tools/ep2_forge/tripo_gen.py text "<prompt>" --out .farm/tripo/<name> [--set k=v ...]

Downloads the model at once (its URL expires in ~5 minutes) to <out>/raw.glb and writes <out>/receipt.json (task id, model, options,
credits before/after). The key works on the .ai host only; the .com docs host answers 401 for it (2026-11-05).
"""
import argparse
import json
import mimetypes
import os
import sys
import time
import urllib.error
import urllib.request
import uuid

BASE = "https://openapi.tripo3d.ai/v3"
DEFAULTS = {"model": "v3.1-20260211", "texture": True, "pbr": True, "texture_quality": "detailed", "geometry_quality": "detailed",
    "face_limit": 30000, "auto_size": True}
POLL_S = 2.0
POLL_MAX_S = 300.0


def key() -> str:
    k = os.environ.get("TRIPO_API_KEY", "")
    if not k:
        sys.exit("TRIPO_API_KEY is not set")
    return k


def call(path: str, data: bytes | None = None, ctype: str = "application/json") -> dict:
    req = urllib.request.Request(BASE + path, data=data, headers={"Authorization": "Bearer " + key()})
    if data is not None:
        req.add_header("Content-Type", ctype)
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            body = json.load(r)
    except urllib.error.HTTPError as e:
        sys.exit("HTTP %d on %s: %s" % (e.code, path, e.read().decode("utf-8", "replace")[:600]))
    if body.get("code") != 0:
        sys.exit("Tripo error on %s: %s" % (path, json.dumps(body)[:600]))
    return body["data"]


def balance() -> float:
    return float(call("/account/balance")["balance"])


def upload(path: str) -> str:
    boundary = uuid.uuid4().hex
    mime = mimetypes.guess_type(path)[0] or "image/jpeg"
    with open(path, "rb") as f:
        payload = f.read()
    head = ('--%s\r\nContent-Disposition: form-data; name="file"; filename="%s"\r\nContent-Type: %s\r\n\r\n'
        % (boundary, os.path.basename(path), mime)).encode()
    data = call("/files", head + payload + ("\r\n--%s--\r\n" % boundary).encode(), "multipart/form-data; boundary=" + boundary)
    return str(data.get("file_token") or data.get("token") or data["image_token"])


def poll(task_id: str) -> dict:
    start = time.time()
    while time.time() - start < POLL_MAX_S:
        t = call("/tasks/" + task_id)
        if t.get("status") in ("success", "failed", "cancelled", "banned", "expired", "unknown"):
            return t
        time.sleep(POLL_S)
    sys.exit("task %s still running after %d s" % (task_id, POLL_MAX_S))


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("mode", choices=["balance", "image", "text"])
    ap.add_argument("input", nargs="?")
    ap.add_argument("--out")
    ap.add_argument("--set", action="append", default=[])
    a = ap.parse_args()
    if a.mode == "balance":
        print("balance", balance())
        return
    opts = dict(DEFAULTS)
    for kv in a.set:
        k, v = kv.split("=", 1)
        opts[k] = json.loads(v) if v[:1] in "0123456789tf[{\"" else v
    os.makedirs(a.out, exist_ok=True)
    before = balance()
    if a.mode == "image":
        opts["input"] = upload(a.input)
        path = "/generation/image-to-model"
    else:
        opts["prompt"] = a.input
        path = "/generation/text-to-model"
    task_id = call(path, json.dumps(opts).encode())["task_id"]
    print("task", task_id, flush=True)
    task = poll(task_id)
    after = balance()
    receipt = {"task_id": task_id, "mode": a.mode, "input": a.input, "options": {k: v for k, v in opts.items() if k != "input"},
        "status": task.get("status"), "error_code": task.get("error_code"), "credits_before": before, "credits_after": after,
        "credits_consumed": task.get("credits_consumed", before - after)}
    if task.get("status") == "success":
        output = task.get("output", {})
        url = output.get("pbr_model") or output.get("model_url") or output.get("model")
        urllib.request.urlretrieve(url, os.path.join(a.out, "raw.glb"))
        receipt["raw"] = os.path.join(a.out, "raw.glb")
    with open(os.path.join(a.out, "receipt.json"), "w") as f:
        json.dump(receipt, f, indent=1)
    print(json.dumps(receipt, indent=1))
    if task.get("status") != "success":
        sys.exit(1)


if __name__ == "__main__":
    main()
