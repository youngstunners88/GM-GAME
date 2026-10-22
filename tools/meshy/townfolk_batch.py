#!/usr/bin/env python3
"""Rebuild every Episode 2 townsperson from the founder's own T-pose photo with Meshy (founder 2026-10-22:
"the townspeople all look the same"). One photo -> one person: Meshy image-to-3D (T-pose, remeshed, PBR) ->
Meshy rig -> ONE merged GLB with that person's own clip set -> clips renamed to the game's names
(Idle/Walk/Observe/Rest/Talk/Inspect/Alert/Greet/Play) -> root motion flattened (the brain moves the body) ->
textures shrunk for the web pack -> src/episode2/extras/people/<file>.

  python3 tools/meshy/townfolk_batch.py plan                 # print the cast + credit estimate, spend nothing
  python3 tools/meshy/townfolk_batch.py run [--only id,id]   # resumable: task ids live in the manifest
  python3 tools/meshy/townfolk_batch.py finish [--only id]   # download/rename/flatten/shrink again from saved tasks

Manifest: design/ep2/town/meshy-cast-20261022/manifest.json (task ids, credits, clip map per person).
Key: MESHY_API_KEY from the environment, never printed. Costs: image-to-3D 30, rig 5, animation 3 per clip.
"""
from __future__ import annotations

import argparse
import base64
import json
import os
import struct
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REFS = ROOT / "design/ep2/town/people-rebuild-20261021/references"
WORK = ROOT / "design/ep2/town/meshy-cast-20261022"
OUT = ROOT / "src/episode2/extras/people"
API = "https://api.meshy.ai/openapi/v1"

# Library action ids (GET /animations/library). Every person gets their OWN idle and their own walk, talk and
# greeting so no two people move alike. Walk clips are flattened to in-place below.
# BOY_WALK / GIRL_WALK were the "Excited Walk" clips (40/39): 10 s acting pieces, not walk loops - re-baked 2026-10-22 as
# Quick Walk (115) and Walking Woman (1) with `rewalk` (3 credits each)
M_WALK, W_WALK, ELDER_WALK, QUICK_WALK, BOY_WALK, GIRL_WALK, SKIP = 30, 1, 121, 115, 115, 1, 118
ALERT = 2
CAST = [
    # id, photo, crop box (or None), file, height m, clip -> action id
    {"id": "clerk", "ref": "town-ref-1hf_4SEXRphX0utxj8bjTLsjsfqFxiM_K.jpg", "file": "townsman_clerk.glb", "h": 1.76,
     "clips": {"Idle": 243, "Walk": M_WALK, "Observe": 336, "Rest": 12, "Talk": 313, "Inspect": 47, "Alert": ALERT, "Greet": 42}},
    {"id": "oldtimer", "ref": "town-ref-1XFWvo-NIOQ_k7fzr8c6wvBqetckd4DFv.jpg", "file": "townsman_oldtimer.glb", "h": 1.69,
     "clips": {"Idle": 244, "Walk": ELDER_WALK, "Observe": 338, "Rest": 38, "Talk": 56, "Inspect": 36, "Alert": ALERT, "Greet": 290}},
    # re-rolled 2026-10-22: with image_enhancement on, Meshy re-posed his T-pose photo into a gunslinger crouch
    {"id": "rancher", "ref": "town-reference.jpg", "file": "townsman_rancher.glb", "h": 1.84, "gen": {"image_enhancement": False},
     "clips": {"Idle": 245, "Walk": M_WALK, "Observe": 336, "Rest": 11, "Talk": 314, "Inspect": 25, "Alert": ALERT, "Greet": 290}},
    {"id": "dressmaker", "ref": "town-ref-1dOSJCq5yxlw5ZpCthbsotOL2UvsDtXWq.jpg", "file": "townswoman_dressmaker.glb", "h": 1.66,
     "clips": {"Idle": 246, "Walk": W_WALK, "Observe": 338, "Rest": 315, "Talk": 309, "Inspect": 48, "Alert": ALERT, "Greet": 290}},
    {"id": "lady", "ref": "town-ref-1UKoNFW1zvswqQRNdVLvusFkYoNWbMUQm.jpg", "file": "townswoman_lady.glb", "h": 1.72,
     "clips": {"Idle": 247, "Walk": W_WALK, "Observe": 336, "Rest": 0, "Talk": 310, "Inspect": 47, "Alert": ALERT, "Greet": 28}},
    {"id": "bald_worker", "ref": "town-ref-14GoIpTFcyyrTF-wGK-B25gynFwmP7HHY.jpg", "file": "townsman_bald_worker.glb", "h": 1.80,
     "clips": {"Idle": 248, "Walk": QUICK_WALK, "Observe": 338, "Rest": 11, "Talk": 56, "Inspect": 36, "Alert": ALERT, "Greet": 290}},
    {"id": "grandma", "ref": "town-ref-1VmiNy2tokmzI286d_T0B80hEgJD328bp.jpg", "file": "townswoman_grandma.glb", "h": 1.57,
     "clips": {"Idle": 249, "Walk": ELDER_WALK, "Observe": 336, "Rest": 38, "Talk": 313, "Inspect": 47, "Alert": ALERT, "Greet": 28}},
    {"id": "grandfather", "ref": "town-ref-1V5c47N0jquR7yEOu9l6yIni-lk9z8yV9.jpg", "crop": [0, 0, 1060, 2048], "file": "townsman_grandfather.glb", "h": 1.73,
     "clips": {"Idle": 250, "Walk": ELDER_WALK, "Observe": 338, "Rest": 38, "Talk": 56, "Inspect": 36, "Alert": ALERT, "Greet": 42}},
    {"id": "grandmother", "ref": "town-ref-1V5c47N0jquR7yEOu9l6yIni-lk9z8yV9.jpg", "crop": [990, 0, 2048, 2048], "file": "townswoman_grandmother.glb", "h": 1.59,
     "clips": {"Idle": 251, "Walk": ELDER_WALK, "Observe": 336, "Rest": 38, "Talk": 309, "Inspect": 48, "Alert": ALERT, "Greet": 290}},
    {"id": "youth", "ref": "town-ref-1VOORJh12iCDg7oJYl86VNO_ZvthA4cqq.jpg", "file": "townsman_youth.glb", "h": 1.67,
     "clips": {"Idle": 252, "Walk": QUICK_WALK, "Observe": 333, "Rest": 12, "Talk": 308, "Inspect": 36, "Alert": ALERT, "Greet": 28, "Play": 61}},
    {"id": "boy", "ref": "town-ref-1ASalMzLNI-KVNyBUAWbaoioGriXAxW0n.jpg", "file": "townsboy.glb", "h": 1.36,
     "clips": {"Idle": 253, "Walk": BOY_WALK, "Observe": 333, "Rest": 11, "Talk": 313, "Inspect": 36, "Alert": ALERT, "Greet": 28, "Play": 61}},
    {"id": "braided_girl", "ref": "town-ref-1TampVjUkhlA5GxEkrEENVgs-RH2MCDg9.jpg", "file": "townsgirl_braided.glb", "h": 1.34,
     "clips": {"Idle": 254, "Walk": SKIP, "Observe": 333, "Rest": 12, "Talk": 309, "Inspect": 48, "Alert": ALERT, "Greet": 28, "Play": 46}},
    {"id": "bob_girl", "ref": "town-ref-1tpM5sMHnAMBluCqGLwo3sTiILwYI7iQP.jpg", "file": "townsgirl_bob.glb", "h": 1.28,
     "clips": {"Idle": 0, "Walk": GIRL_WALK, "Observe": 333, "Rest": 11, "Talk": 310, "Inspect": 47, "Alert": ALERT, "Greet": 28, "Play": 44}},
    # the jail prisoner: separate story actor (gold_town.gd), same pipeline
    {"id": "prisoner", "ref": "town-ref-1OPVPqj8P3sVpi_bJN90dJqyqFDoqoLVV.jpg", "file": "prisoner_accomplice.glb", "h": 1.74,
     "clips": {"Idle": 244, "Walk": M_WALK, "Observe": 338, "Rest": 12, "Talk": 308, "Inspect": 36, "Alert": ALERT, "Greet": 290}},
]
COST = {"model": 30, "rig": 5, "clip": 3}


def _req(method: str, path: str, body: dict | None = None, tries: int = 4) -> dict:
    key = os.environ.get("MESHY_API_KEY", "")
    if not key:
        sys.exit("STOP: MESHY_API_KEY is not set")
    data = json.dumps(body).encode() if body is not None else None
    for i in range(tries):
        r = urllib.request.Request(f"{API}{path}", data=data, method=method,
                                   headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json"})
        try:
            with urllib.request.urlopen(r, timeout=180) as resp:
                return json.loads(resp.read())
        except urllib.error.HTTPError as e:
            msg = e.read()[:300]
            if e.code in (429, 500, 502, 503) and i < tries - 1:
                time.sleep(10 * (i + 1))
                continue
            raise RuntimeError(f"Meshy {method} {path} -> HTTP {e.code}: {msg!r}")
        except (urllib.error.URLError, TimeoutError):
            if i < tries - 1:
                time.sleep(5 * (i + 1))
                continue
            raise
    raise RuntimeError("unreachable")


def _load() -> dict:
    p = WORK / "manifest.json"
    return json.loads(p.read_text()) if p.exists() else {"people": {}}


def _save(m: dict) -> None:
    WORK.mkdir(parents=True, exist_ok=True)
    (WORK / "manifest.json").write_text(json.dumps(m, indent=2) + "\n")


def _clip_ids(c: dict) -> list[int]:
    # one action per game clip, in a fixed order; duplicates (same library clip in two slots) are requested once
    seen: list[int] = []
    for v in c["clips"].values():
        if v not in seen:
            seen.append(v)
    return seen


def plan() -> int:
    total = 0
    for c in CAST:
        n = len(_clip_ids(c))
        cost = COST["model"] + COST["rig"] + COST["clip"] * n
        total += cost
        print(f"{c['id']:13s} {c['file']:28s} h={c['h']:.2f}  clips={n:2d}  credits~{cost}")
    print(f"TOTAL ~{total} credits for {len(CAST)} people")
    return 0


def _image_uri(c: dict) -> str:
    src = REFS / c["ref"]
    if c.get("crop"):
        from PIL import Image
        WORK.mkdir(parents=True, exist_ok=True)
        dst = WORK / f"crop_{c['id']}.jpg"
        Image.open(src).crop(tuple(c["crop"])).save(dst, quality=93)
        src = dst
    return "data:image/jpeg;base64," + base64.b64encode(src.read_bytes()).decode()


def _poll(path: str) -> dict:
    t = _req("GET", path)
    return t


def run(only: set[str]) -> int:
    m = _load()
    people = m["people"]
    todo = [c for c in CAST if not only or c["id"] in only]
    # Meshy's plan caps queued tasks (429 NoMorePendingTasks): keep a rolling queue - submit while it accepts, back off
    # on 429, and let each person advance model -> rig -> anim -> finish independently.
    for c in todo:
        row = people.setdefault(c["id"], {"file": c["file"], "ref": c["ref"], "h": c["h"]})
        row["clips"] = c["clips"]
        if row.get("stage") == "failed" and not row.get("model_ok"):
            row.pop("stage", None)
            row.pop("model_task", None)
            row.pop("error", None)
    _save(m)
    pending = {c["id"] for c in todo if people[c["id"]].get("stage") != "done"}
    while pending:
        busy = False
        for c in todo:
            cid = c["id"]
            if cid not in pending:
                continue
            row = people[cid]
            if not row.get("model_task"):
                if busy:
                    continue
                try:
                    body = {"image_url": _image_uri(c), "ai_model": "latest", "pose_mode": "t-pose", "should_remesh": True,
                            "topology": "triangle", "target_polycount": 16000, "should_texture": True, "enable_pbr": True,
                            "texture_resolution": "2k", "target_formats": ["glb"], "origin_at": "bottom"}
                    body.update(c.get("gen", {}))      # per-person overrides (e.g. the rancher re-roll)
                    row["model_task"] = _req("POST", "/image-to-3d", body, tries=1)["result"]
                    print(f"[{cid}] model task {row['model_task']}", flush=True)
                    _save(m)
                except RuntimeError as e:
                    if "429" not in str(e):
                        raise
                    busy = True
                continue
            stage = _advance(c, row)
            _save(m)
            if stage in ("done", "failed"):
                pending.discard(cid)
                print(f"[{cid}] {stage} {row.get('error', '')}", flush=True)
        if pending:
            time.sleep(20)
    failed = [cid for cid, r in people.items() if r.get("stage") == "failed"]
    print("FAILED:", failed if failed else "none")
    return 1 if failed else 0


def _advance(c: dict, row: dict) -> str:
    """One poll step of the per-person state machine: model -> rig -> anim -> finish."""
    try:
        if not row.get("model_ok"):
            t = _poll(f"/image-to-3d/{row['model_task']}")
            if t["status"] in ("FAILED", "CANCELED", "EXPIRED"):
                row["stage"], row["error"] = "failed", str(t.get("task_error"))
                return "failed"
            if t["status"] != "SUCCEEDED":
                return "model"
            row["model_ok"] = True
            row["model_credits"] = t.get("consumed_credits")
        if not row.get("rig_task"):
            row["rig_task"] = _req("POST", "/rigging", {"input_task_id": row["model_task"], "height_meters": c["h"]})["result"]
            return "rig"
        if not row.get("rig_ok"):
            t = _poll(f"/rigging/{row['rig_task']}")
            if t["status"] in ("FAILED", "CANCELED", "EXPIRED"):
                row["stage"], row["error"] = "failed", str(t.get("task_error"))
                return "failed"
            if t["status"] != "SUCCEEDED":
                return "rig"
            row["rig_ok"] = True
        if not row.get("anim_task"):
            row["actions"] = _clip_ids(c)
            row["anim_task"] = _req("POST", "/animations", {"rig_task_id": row["rig_task"], "action_ids": row["actions"],
                                                             "post_process": {"operation_type": "change_fps", "fps": 30}})["result"]
            return "anim"
        if not row.get("anim_url"):
            t = _poll(f"/animations/{row['anim_task']}")
            if t["status"] in ("FAILED", "CANCELED", "EXPIRED"):
                row["stage"], row["error"] = "failed", str(t.get("task_error"))
                return "failed"
            if t["status"] != "SUCCEEDED":
                return "anim"
            row["anim_url"] = t["result"]["animation_glb_url"].split("?")[0]   # signature stripped; finish re-asks the task
        finish(c, row)
        row["stage"] = "done"
        return "done"
    except RuntimeError as e:
        if "429" in str(e):
            return "queued"
        row["stage"], row["error"] = "failed", str(e)
        return "failed"


# --- GLB post-processing -------------------------------------------------------------------------------------------

def _read_glb(p: Path) -> tuple[dict, bytearray]:
    b = p.read_bytes()
    assert struct.unpack_from("<I", b, 0)[0] == 0x46546C67, "not a GLB"
    jl = struct.unpack_from("<I", b, 12)[0]
    js = json.loads(b[20:20 + jl])
    off = 20 + jl
    bl = struct.unpack_from("<I", b, off)[0]
    return js, bytearray(b[off + 8: off + 8 + bl])


def _write_glb(p: Path, js: dict, binc: bytearray) -> None:
    j = json.dumps(js, separators=(",", ":")).encode()
    j += b" " * ((4 - len(j) % 4) % 4)
    binc += b"\0" * ((4 - len(binc) % 4) % 4)
    total = 12 + 8 + len(j) + 8 + len(binc)
    p.write_bytes(struct.pack("<III", 0x46546C67, 2, total) + struct.pack("<II", len(j), 0x4E4F534A) + j
                  + struct.pack("<II", len(binc), 0x004E4942) + bytes(binc))


def _accessor_floats(js: dict, binc: bytearray, idx: int) -> tuple[int, int, int]:
    a = js["accessors"][idx]
    bv = js["bufferViews"][a["bufferView"]]
    comps = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}[a["type"]]
    start = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    stride = bv.get("byteStride", 4 * comps)
    return start, stride, a["count"]


def _library() -> dict:
    # cached under raw/ (gitignored): the library's "key" fields trip gitleaks' generic-api-key rule (clip names, not secrets)
    p = WORK / "raw" / "library.json"
    if not p.exists():
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(json.dumps(_req("GET", "/animations/library?page_size=1000")))
    return {int(a["action_id"]): a for a in json.loads(p.read_text())}


def _quat_mat(q):
    x, y, z, w = q
    return [[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
            [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
            [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]]


def _sample(js, binc, sampler, comps):
    start, stride, count = _accessor_floats(js, binc, sampler["output"])
    vals = [struct.unpack_from("<" + "f" * comps, binc, start + k * stride) for k in range(count)]
    ts, tstride, tcount = _accessor_floats(js, binc, sampler["input"])
    times = [struct.unpack_from("<f", binc, ts + k * tstride)[0] for k in range(tcount)]
    return times, vals


def foot_speed(js: dict, binc: bytearray, anim: dict) -> float:
    """Ground speed (in the skeleton's own units per second) implied by an in-place walk: forward kinematics of both
    feet relative to the hips; while a foot is planted (the lower one) it slides back at exactly the walking speed."""
    nodes = js["nodes"]
    parent = {}
    for i, n in enumerate(nodes):
        for c in n.get("children", []):
            parent[c] = i
    tracks = {}
    times = []
    for ch in anim["channels"]:
        t = ch["target"]
        if t.get("path") in ("rotation", "translation"):
            tm, vals = _sample(js, binc, anim["samplers"][ch["sampler"]], 4 if t["path"] == "rotation" else 3)
            tracks[(t["node"], t["path"])] = vals
            if len(tm) > len(times):
                times = tm
    names = {n.get("name"): i for i, n in enumerate(nodes)}
    hips = names.get("Hips")
    feet = [names.get("LeftFoot"), names.get("RightFoot")]
    if hips is None or None in feet or len(times) < 3:
        return 0.0

    def world(node, k):  # position of node relative to the hips' parent frame
        chain = []
        i = node
        while i is not None:
            chain.append(i)
            if i == hips:
                break
            i = parent.get(i)
        pos = [0.0, 0.0, 0.0]
        for i in chain:  # child -> up: p = R*p + T
            n = nodes[i]
            q = tracks.get((i, "rotation"), [None] * len(times))[min(k, len(tracks.get((i, "rotation"), [0])) - 1)] \
                if (i, "rotation") in tracks else n.get("rotation", [0, 0, 0, 1])
            tr = tracks[(i, "translation")][min(k, len(tracks[(i, "translation")]) - 1)] if (i, "translation") in tracks \
                else n.get("translation", [0, 0, 0])
            m = _quat_mat(q)
            pos = [m[r][0] * pos[0] + m[r][1] * pos[1] + m[r][2] * pos[2] + tr[r] for r in range(3)]
        return pos

    speeds = []
    for k in range(len(times) - 1):
        dt = times[k + 1] - times[k]
        if dt <= 0:
            continue
        a = [world(f, k) for f in feet]
        b = [world(f, k + 1) for f in feet]
        low = 0 if a[0][1] < a[1][1] else 1
        dx, dz = b[low][0] - a[low][0], b[low][2] - a[low][2]
        speeds.append((dx * dx + dz * dz) ** 0.5 / dt)
    speeds.sort()
    return speeds[len(speeds) // 2] if speeds else 0.0


def rename_and_flatten(path: Path, clips: dict) -> list[str]:
    """Name each library clip after its game slot (a clip used by two slots is duplicated by reference) and pin the
    hips' horizontal travel to its first frame, so the brain's own movement is the only travel."""
    js, binc = _read_glb(path)
    anims = js.get("animations", [])
    lib = {}
    for a in anims:
        lib.setdefault(a.get("name", ""), a)
    order = list(dict.fromkeys(clips.values()))
    # Meshy names merged clips after the library entry; fall back to request order if a name is not found
    if len(anims) != len(order):
        raise RuntimeError(f"{path.name}: {len(anims)} clips for {len(order)} requested actions")
    names = _library()
    by_action = {}
    for i, aid in enumerate(order):
        want = {names.get(aid, {}).get("name", "").lower(), names.get(aid, {}).get("key", "").lower()}
        hit = [a for a in anims if a.get("name", "").lower().split("|")[-1] in want]
        by_action[aid] = hit[0] if hit else anims[i]
    nodes = js["nodes"]
    hips = {i for i, n in enumerate(nodes) if n.get("name", "").lower().split(":")[-1] in ("hips", "mixamorig_hips", "pelvis", "root")}
    out_anims = []
    for slot, aid in clips.items():
        src = by_action[aid]
        a = json.loads(json.dumps(src))
        a["name"] = slot
        out_anims.append(a)
    # the walk clip's own ground speed, in hip heights per second (unit-free; the armature is scaled)
    walk_rate = 0.0
    wa = by_action.get(clips.get("Walk", -1))
    hip_node = next((i for i, n in enumerate(nodes) if n.get("name") == "Hips"), None)
    if wa is not None and hip_node is not None:
        hip_y = abs(nodes[hip_node].get("translation", [0, 1, 0])[1]) or 1.0
        walk_rate = foot_speed(js, binc, wa) / hip_y
    rename_and_flatten.walk_rate = walk_rate
    for a in {id(x): x for x in anims}.values():
        for ch in a["channels"]:
            t = ch["target"]
            if t.get("path") != "translation" or t.get("node") not in hips:
                continue
            s = a["samplers"][ch["sampler"]]
            start, stride, count = _accessor_floats(js, binc, s["output"])
            x0, _, z0 = struct.unpack_from("<fff", binc, start)
            for k in range(count):
                o = start + k * stride
                _, y, _ = struct.unpack_from("<fff", binc, o)
                struct.pack_into("<fff", binc, o, x0, y, z0)
    js["animations"] = out_anims
    _write_glb(path, js, binc)
    return [a["name"] for a in out_anims]


def graft_pbr(dst: Path, model_glb: Path) -> bool:
    """The rigged/animated GLB keeps the model's UV atlas but drops its normal and metal-rough maps. Copy those two
    images from the image-to-3D GLB into the animated GLB's material (same triangles, same UVs - checked by index count)."""
    mj, mb = _read_glb(model_glb)
    dj, db = _read_glb(dst)
    mi = mj["meshes"][0]["primitives"][0]["indices"]
    di = dj["meshes"][0]["primitives"][0]["indices"]
    if mj["accessors"][mi]["count"] != dj["accessors"][di]["count"]:
        return False
    mmat = mj["materials"][0]
    dmat = dj["materials"][0]
    pbr = dmat.setdefault("pbrMetallicRoughness", {})

    def copy_tex(tex_index: int) -> int:
        img = mj["images"][mj["textures"][tex_index]["source"]]
        bv = mj["bufferViews"][img["bufferView"]]
        data = bytes(mb[bv.get("byteOffset", 0): bv.get("byteOffset", 0) + bv["byteLength"]])
        while len(db) % 4:
            db.append(0)
        dj["bufferViews"].append({"buffer": 0, "byteOffset": len(db), "byteLength": len(data)})
        db.extend(data)
        dj.setdefault("images", []).append({"bufferView": len(dj["bufferViews"]) - 1, "mimeType": img.get("mimeType", "image/png")})
        tex = {"source": len(dj["images"]) - 1}
        if dj.get("samplers"):
            tex["sampler"] = 0
        dj.setdefault("textures", []).append(tex)
        return len(dj["textures"]) - 1

    if "normalTexture" in mmat:
        dmat["normalTexture"] = {"index": copy_tex(mmat["normalTexture"]["index"])}
    mr = mmat.get("pbrMetallicRoughness", {}).get("metallicRoughnessTexture")
    if mr is not None:
        pbr["metallicRoughnessTexture"] = {"index": copy_tex(mr["index"])}
        pbr["metallicFactor"] = 1.0
        pbr["roughnessFactor"] = 1.0
    dj["buffers"][0]["byteLength"] = len(db)
    _write_glb(dst, dj, db)
    return True


def graft_clip(dst: Path, src: Path, slot: str) -> None:
    """Replace the `slot` animation in dst with the single animation in src (same Meshy rig: nodes matched by name)."""
    dj, db = _read_glb(dst)
    sj, sb = _read_glb(src)
    by_name = {n.get("name"): i for i, n in enumerate(dj["nodes"])}
    anim = sj["animations"][0]
    acc_map: dict[int, int] = {}

    def copy_acc(i: int) -> int:
        if i in acc_map:
            return acc_map[i]
        a = dict(sj["accessors"][i])
        bv = sj["bufferViews"][a["bufferView"]]
        data = bytes(sb[bv.get("byteOffset", 0): bv.get("byteOffset", 0) + bv["byteLength"]])
        while len(db) % 4:
            db.append(0)
        nbv = {"buffer": 0, "byteOffset": len(db), "byteLength": len(data)}
        if "byteStride" in bv:
            nbv["byteStride"] = bv["byteStride"]
        dj["bufferViews"].append(nbv)
        db.extend(data)
        a["bufferView"] = len(dj["bufferViews"]) - 1
        dj["accessors"].append(a)
        acc_map[i] = len(dj["accessors"]) - 1
        return acc_map[i]

    samplers, channels = [], []
    for ch in anim["channels"]:
        name = sj["nodes"][ch["target"]["node"]].get("name")
        if name not in by_name:
            continue
        sm = anim["samplers"][ch["sampler"]]
        samplers.append({"input": copy_acc(sm["input"]), "output": copy_acc(sm["output"]),
                         "interpolation": sm.get("interpolation", "LINEAR")})
        channels.append({"sampler": len(samplers) - 1, "target": {"node": by_name[name], "path": ch["target"]["path"]}})
    new = {"name": slot, "samplers": samplers, "channels": channels}
    dj["animations"] = [new if a.get("name") == slot else a for a in dj["animations"]]
    dj["buffers"][0]["byteLength"] = len(db)
    _write_glb(dst, dj, db)


def rewalk(c: dict, row: dict, action: int) -> None:
    """Re-bake ONE library clip (3 credits) on the existing rig and graft it in as the Walk."""
    aid = _req("POST", "/animations", {"rig_task_id": row["rig_task"], "action_ids": [action],
                                       "post_process": {"operation_type": "change_fps", "fps": 30}})["result"]
    while True:
        t = _req("GET", f"/animations/{aid}")
        if t["status"] == "SUCCEEDED":
            break
        if t["status"] in ("FAILED", "CANCELED", "EXPIRED"):
            raise RuntimeError(f"rewalk {c['id']}: {t.get('task_error')}")
        time.sleep(10)
    one = WORK / "raw" / f"walk_{action}_{c['file']}"
    urllib.request.urlretrieve(t["result"]["animation_glb_url"], one)
    raw = WORK / "raw" / c["file"]
    # keep the original merged download; the graft goes into it so `finish` stays reproducible
    graft_clip(raw, one, _raw_name(raw, c, "Walk"))
    row.setdefault("rewalk", []).append({"action": action, "anim_task": aid})


def _raw_name(raw: Path, c: dict, slot: str) -> str:
    js, _ = _read_glb(raw)
    order = list(dict.fromkeys(c["clips"].values()))
    return js["animations"][order.index(c["clips"][slot])]["name"]


def normalize_armature(path: Path) -> float:
    """Meshy rigs keep the bones in centimetres under an 'Armature' node scaled 0.01, with the mesh in metres. glTF viewers
    cope, but Ep2TownFolk fits a character by its UNSKINNED mesh box (x0.01 -> it scales the model x100) while Godot draws the
    skin from the bones -> people 100x too big in the game. Bake the armature scale into the joints so everything is metres:
    joint translations (rest + every animation) x s, inverse bind matrices left-multiplied by S (rows 0-2 x s), armature 1."""
    js, binc = _read_glb(path)
    nodes = js["nodes"]
    arm = next((i for i, n in enumerate(nodes) if n.get("name") == "Armature" and n.get("scale")), None)
    if arm is None:
        return 1.0
    sc = nodes[arm]["scale"]
    if abs(sc[0] - sc[1]) > 1e-6 or abs(sc[0] - sc[2]) > 1e-6:
        raise RuntimeError(f"{path.name}: non-uniform armature scale {sc}")
    k = float(sc[0])
    if abs(k - 1.0) < 1e-9:
        return 1.0
    mesh_nodes = {i for i, n in enumerate(nodes) if "mesh" in n}
    under = set()
    stack = list(nodes[arm].get("children", []))
    while stack:
        i = stack.pop()
        under.add(i)
        stack.extend(nodes[i].get("children", []))
    joints = under - mesh_nodes
    for i in joints:
        if "translation" in nodes[i]:
            nodes[i]["translation"] = [v * k for v in nodes[i]["translation"]]
    done: set[int] = set()
    for a in js.get("animations", []):
        for ch in a["channels"]:
            t = ch["target"]
            if t.get("path") != "translation" or t.get("node") not in joints:
                continue
            out = a["samplers"][ch["sampler"]]["output"]
            if out in done:
                continue
            done.add(out)
            start, stride, count = _accessor_floats(js, binc, out)
            for j in range(count):
                o = start + j * stride
                x, y, z = struct.unpack_from("<fff", binc, o)
                struct.pack_into("<fff", binc, o, x * k, y * k, z * k)
            acc = js["accessors"][out]
            for key in ("min", "max"):
                if key in acc:
                    acc[key] = [v * k for v in acc[key]]
    for skin in js.get("skins", []):
        acc = js["accessors"][skin["inverseBindMatrices"]]
        bv = js["bufferViews"][acc["bufferView"]]
        start = bv.get("byteOffset", 0) + acc.get("byteOffset", 0)
        for j in range(acc["count"]):
            o = start + j * 64
            m = list(struct.unpack_from("<16f", binc, o))
            for col in range(4):           # column-major: element (row, col) at col*4 + row; scale rows 0-2
                for row in range(3):
                    m[col * 4 + row] *= k
            struct.pack_into("<16f", binc, o, *m)
    nodes[arm]["scale"] = [1.0, 1.0, 1.0]
    _write_glb(path, js, binc)
    return k


def finish(c: dict, row: dict) -> None:
    raw = WORK / "raw" / c["file"]
    raw.parent.mkdir(parents=True, exist_ok=True)
    if not raw.exists():
        # signed CDN URLs expire (and are not kept in the manifest): ask the animation task for a fresh one
        t = _req("GET", f"/animations/{row['anim_task']}")
        urllib.request.urlretrieve(t["result"]["animation_glb_url"], raw)
    work = WORK / "raw" / ("named_" + c["file"])
    work.write_bytes(raw.read_bytes())
    row["clip_names"] = rename_and_flatten(work, c["clips"])
    model = WORK / "raw" / ("model_" + c["file"])
    if not model.exists():
        t = _req("GET", f"/image-to-3d/{row['model_task']}")
        urllib.request.urlretrieve(t["model_urls"]["glb"], model)
    row["pbr_grafted"] = graft_pbr(work, model)
    row["armature_scale_baked"] = normalize_armature(work)
    row["walk_speed"] = round(rename_and_flatten.walk_rate * 0.53 * c["h"], 3)
    OUT.mkdir(parents=True, exist_ok=True)
    dst = OUT / c["file"]
    subprocess.run([sys.executable, str(ROOT / "tools/meshy/shrink_glb.py"), str(work), str(dst), "--max", "1024", "--aux-max", "512"],
                   check=True)
    row["bytes"] = dst.stat().st_size


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("cmd", choices=["plan", "run", "finish", "rewalk"])
    ap.add_argument("--action", type=int, default=0, help="rewalk: library action id of the new walk")
    ap.add_argument("--only", default="")
    a = ap.parse_args()
    only = {x for x in a.only.split(",") if x}
    if a.cmd == "plan":
        return plan()
    if a.cmd == "run":
        return run(only)
    m = _load()
    for c in CAST:
        if only and c["id"] not in only:
            continue
        row = m["people"].get(c["id"], {})
        if a.cmd == "rewalk":
            rewalk(c, row, a.action)
        if row.get("anim_url"):
            finish(c, row)
            print(f"[{c['id']}] finished -> {row['clip_names']}")
    _save(m)
    return 0


if __name__ == "__main__":
    sys.exit(main())
