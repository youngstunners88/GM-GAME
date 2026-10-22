#!/usr/bin/env python3
"""Download Mixamo animations (FBX) from the terminal for the game's humanoids (skill ep2-mixamo-pipeline).

Uses the standalone client from HaD0Yun/unity-mcp-mixamo (installed at ~/tools/unity-mcp-mixamo; it needs no Unity). Mixamo is Adobe's
service: every call needs the account's access token. THE TOKEN IS A CREDENTIAL: it is never printed, never committed and never pasted
into chat. The founder writes it once into ~/.mixamo_mcp_token (mode 600) with a hidden prompt (see the skill), then:

  uv run --no-project --with httpx --with pydantic python tools/ep2_motion/mixamo_dl.py status
  ... mixamo_dl.py search "walking"
  ... mixamo_dl.py get "Walking" --out ~/tools/mocap/mixamo   # downloads <name>.fbx (without skin, 30 fps)
Exit 2 = no/invalid token (nothing was sent anywhere except mixamo.com / adobe's API through the client).
"""
import argparse
import asyncio
import sys
from pathlib import Path

CLIENT_SRC = Path.home() / "tools" / "unity-mcp-mixamo" / "Server" / "src"
sys.path.insert(0, str(CLIENT_SRC))
try:
    from mixamo_mcp.client import MixamoClient
except Exception as e:  # noqa: BLE001
    sys.exit(f"cannot import the Mixamo client from {CLIENT_SRC}: {e}\n(clone https://github.com/HaD0Yun/unity-mcp-mixamo.git into ~/tools)")


async def main() -> int:
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("status")
    s = sub.add_parser("search")
    s.add_argument("query")
    s.add_argument("--limit", type=int, default=8)
    g = sub.add_parser("get")
    g.add_argument("name")
    g.add_argument("--out", default=str(Path.home() / "tools" / "mocap" / "mixamo"))
    a = ap.parse_args()
    c = MixamoClient()
    if not c.access_token:
        print("no Mixamo token stored (~/.mixamo_mcp_token). See skill ep2-mixamo-pipeline: the founder writes it with a hidden prompt.")
        return 2
    try:
        if a.cmd == "status":
            ok = await c.validate_token()
            print("token valid" if ok else "token rejected (expired?) - write a fresh one")
            return 0 if ok else 2
        if a.cmd == "search":
            r = await c.search(a.query, limit=a.limit)
            for an in r.animations:
                print(f"{an.id}\t{an.name}")
            print(f"{r.total} total")
            return 0
        if a.cmd == "get":
            Path(a.out).mkdir(parents=True, exist_ok=True)
            r = await c.download(a.name, a.out)
            print(("ok " + str(getattr(r, "file_path", ""))) if r.success else ("failed: " + str(r.error)))
            return 0 if r.success else 1
    finally:
        await c.close()
    return 0


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
