#!/usr/bin/env python3
"""Talk to the founder's Runpod pod from the agent container (skill ep2-cloud-gpu-runpod).

  python3 tools/ep2_runpod/pod_run.py status                      pods: id, name, state, $/h, ports   (REST, read-only)
  python3 tools/ep2_runpod/pod_run.py exec  "<shell command>" [--pod ID] [--timeout 600]
  python3 tools/ep2_runpod/pod_run.py put   local_file remote_path [--pod ID]
  python3 tools/ep2_runpod/pod_run.py get   remote_path local_file [--pod ID]
  python3 tools/ep2_runpod/pod_run.py setup-blender [--pod ID]    the doc's Blender 4.5.3 headless install under /workspace/blender (idempotent)

Why Jupyter: raw TCP to the pod's SSH port is blocked from the agent container, https://<id>-8888.proxy.runpod.net is not. The pod's Jupyter
password is read from the pod's own env through the REST API (key: RUNPOD_API from the environment). Nothing secret is printed, logged or written.
Never creates / stops / terminates a pod - that is the founder's call.
"""
import argparse
import base64
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

REST = "https://rest.runpod.io/v1"
BLENDER_URL = "https://download.blender.org/release/Blender4.5/blender-4.5.3-linux-x64.tar.xz"


def _key() -> str:
    k = os.environ.get("RUNPOD") or os.environ.get("RUNPOD_API") or os.environ.get("RUNPOD_API_KEY", "")
    if not k:
        sys.exit("Runpod key is not injected into this process (checked RUNPOD, RUNPOD_API, RUNPOD_API_KEY)")
    return k


def rest(path: str):
    req = urllib.request.Request(REST + path, headers={"Authorization": "Bearer " + _key(), "User-Agent": "curl/8.5.0"})
    with urllib.request.urlopen(req, timeout=40) as r:
        return json.loads(r.read())


def pods():
    return rest("/pods")


def pick(pod_id: str = ""):
    ps = [p for p in pods() if p.get("desiredStatus") == "RUNNING"]
    if pod_id:
        ps = [p for p in ps if p["id"] == pod_id]
    if not ps:
        sys.exit("no RUNNING pod (ask the founder to start one - this tool never starts pods)")
    return ps[0]


def jupyter(pod):
    """(base url, headers) for the pod's Jupyter through the Runpod proxy; auth by the pod's own JUPYTER_PASSWORD."""
    full = rest("/pods/" + pod["id"])
    env = full.get("env") or {}
    pw = env.get("JUPYTER_PASSWORD") or env.get("JUPYTER_TOKEN") or ""
    base = "https://%s-8888.proxy.runpod.net" % pod["id"]
    hdr = {"Authorization": "token " + pw} if pw else {}
    return base, hdr


def jreq(base, hdr, path, data=None, method=None, timeout=60):
    body = None if data is None else json.dumps(data).encode()
    h = dict(hdr)
    h["User-Agent"] = "curl/8.5.0"
    if body is not None:
        h["Content-Type"] = "application/json"
    req = urllib.request.Request(base + path, data=body, headers=h, method=method or ("PUT" if body else "GET"))
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read() or b"{}")


def exec_cmd(pod, cmd: str, timeout: int = 600) -> str:
    """Run a shell command on the pod through a Jupyter terminal (websocket), return its output. Long jobs: put them in `tmux` yourself."""
    import ssl
    import websocket        # pip install websocket-client
    base, hdr = jupyter(pod)
    term = jreq(base, hdr, "/api/terminals", {}, "POST")
    url = "wss://%s-8888.proxy.runpod.net/terminals/websocket/%s" % (pod["id"], term["name"])
    ws = websocket.create_connection(url, header=["%s: %s" % kv for kv in hdr.items()] + ["User-Agent: curl/8.5.0"], timeout=30,
                                     sslopt={"cert_reqs": ssl.CERT_REQUIRED})
    mark = "__DONE_%d__" % int(time.time())
    ws.send(json.dumps(["stdin", "%s\recho %s$?\r" % (cmd, mark)]))
    out, end = "", time.time() + timeout
    ws.settimeout(15)
    while time.time() < end:
        try:
            m = json.loads(ws.recv())
        except websocket.WebSocketTimeoutException:
            continue
        if m and m[0] == "stdout":
            out += m[1]
            if mark in out.split(cmd)[-1] and out.rstrip().split(mark)[-1].strip().isdigit():
                break
    ws.close()
    try:
        jreq(base, hdr, "/api/terminals/" + term["name"], None, "DELETE")
    except Exception:
        pass
    import re
    return re.sub(r'\x1b\[[0-9;?]*[a-zA-Z]|\x1b\][^\x07]*\x07', '', out)


def main():
    ap = argparse.ArgumentParser()
    sp = ap.add_subparsers(dest="cmd", required=True)
    sp.add_parser("status")
    for n in ("exec", "put", "get", "setup-blender"):
        p = sp.add_parser(n)
        p.add_argument("args", nargs="*")
        p.add_argument("--pod", default="")
        p.add_argument("--timeout", type=int, default=600)
    a = ap.parse_args()
    if a.cmd == "status":
        for p in pods():
            print(p["id"], p.get("name"), p.get("desiredStatus"), "$%s/h" % p.get("costPerHr"), p.get("ports"), "volume %sGB" % p.get("volumeInGb"))
        return
    pod = pick(a.pod)
    if a.cmd == "put":
        local, remote = a.args
        base, hdr = jupyter(pod)
        data = open(local, "rb").read()
        jreq(base, hdr, "/api/contents/" + urllib.parse.quote(remote.lstrip("/")), {"type": "file", "format": "base64", "content": base64.b64encode(data).decode()}, timeout=600)
        print("uploaded", local, "->", remote, len(data), "bytes")
    elif a.cmd == "get":
        remote, local = a.args
        base, hdr = jupyter(pod)
        r = jreq(base, hdr, "/api/contents/" + urllib.parse.quote(remote.lstrip("/")) + "?format=base64&type=file", timeout=600)
        open(local, "wb").write(base64.b64decode(r["content"]))
        print("downloaded", remote, "->", local)
    elif a.cmd == "exec":
        print(exec_cmd(pod, " ".join(a.args), a.timeout))
    elif a.cmd == "setup-blender":
        cmd = ("test -x /workspace/blender/blender || (apt update && apt install -y wget xz-utils libx11-6 libxi6 libxxf86vm1 libxfixes3 libxrender1 libgl1 libxkbcommon0 && "
               "cd /workspace && wget -q %s && tar -xf blender-4.5.3-linux-x64.tar.xz && mv blender-4.5.3-linux-x64 blender); nvidia-smi -L; /workspace/blender/blender -b --version" % BLENDER_URL)
        print(exec_cmd(pod, cmd, 1800))


if __name__ == "__main__":
    main()
