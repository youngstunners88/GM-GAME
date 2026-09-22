#!/usr/bin/env python3
"""GM-GAME toolkit — an MCP server that fronts this repo's real scripts as typed tools.

Why this exists (it is the abstraction layer):
Before, running a gate meant the agent read a skill file to remember the incantation,
then composed a shell line, then parsed free-form output — three context-expensive steps
that also drift. Here each gate is ONE typed call returning a small structured result.
The skill prose stays for humans; the agent just calls the tool.

Zero third-party dependencies on purpose. This process guards releases and secrets, so
it must not carry a supply chain. Stdlib JSON-RPC 2.0 over stdio is the whole protocol.

Separation of concerns:
  - the .sh/.mjs scripts own the ACTUAL logic  (single implementation, also used by CI)
  - this server only ADAPTS them to typed calls (no logic is duplicated here)
Nothing in this file reimplements a check. If a gate changes, it changes in the script.
"""
from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Callable

ROOT = Path(__file__).resolve().parents[2]
PROTOCOL_VERSION = "2024-11-05"
MAX_OUTPUT = 4000  # keep results small — the point is to SAVE context, not move the dump


def _run(cmd: list[str], timeout: int) -> dict[str, Any]:
    """Run a repo script and return a compact, structured result."""
    exe = shutil.which(cmd[0])
    if exe is None:
        return {"ok": False, "error": f"{cmd[0]} not found on PATH"}
    try:
        p = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        return {"ok": False, "error": f"timed out after {timeout}s"}
    out = ((p.stdout or "") + (p.stderr or "")).strip()
    truncated = len(out) > MAX_OUTPUT
    return {
        "ok": p.returncode == 0,
        "exit_code": p.returncode,
        "output": ("…(head truncated)…\n" + out[-MAX_OUTPUT:]) if truncated else out,
        "truncated": truncated,
    }


@dataclass(frozen=True)
class Tool:
    name: str
    description: str
    schema: dict[str, Any]
    fn: Callable[[dict[str, Any]], dict[str, Any]]


def _no_args() -> dict[str, Any]:
    return {"type": "object", "properties": {}, "additionalProperties": False}


TOOLS: list[Tool] = [
    Tool(
        "security_gate",
        "Run the 18-check security sentinel (the single implementation also used by CI and "
        "release). Returns pass/fail counts and any blockers. NOTE: it scans `git ls-files`, "
        "so stage new files with `git add` FIRST or it silently scans nothing.",
        _no_args(),
        lambda a: _run(["bash", "scripts/security-sentinel.sh"], 180),
    ),
    Tool(
        "farm_validate",
        "Validate the tool-farm registry and routing table against their JSON schemas, plus "
        "cross-file invariants (no duplicate ids; ADOPT requires having actually run the tool "
        "here; STEAL-IDEAS-ONLY must record which pattern was taken). Fails closed.",
        _no_args(),
        lambda a: _run(["node", "scripts/farm/farm.mjs", "validate"], 60),
    ),
    Tool(
        "route_task",
        "Classify a task and return the model tier, context manifest, skills and gates to use. "
        "Call this BEFORE starting work to avoid loading context the task does not need — it is "
        "the main token-efficiency lever. Falls back to the safest class if the engine is down.",
        {
            "type": "object",
            "properties": {"task": {"type": "string", "description": "Plain-words description of the task."}},
            "required": ["task"],
            "additionalProperties": False,
        },
        lambda a: _run(["python3", "scripts/farm/route.py", "--json", str(a["task"])], 90),
    ),
    Tool(
        "tool_verdict",
        "Explain why a given external tool was adopted, mined for patterns, or rejected. Use "
        "this instead of re-researching a tool that has already been evaluated.",
        {
            "type": "object",
            "properties": {"id": {"type": "string", "description": "Registry id, e.g. 'pijev' or 'omniroute'."}},
            "required": ["id"],
            "additionalProperties": False,
        },
        lambda a: _run(["node", "scripts/farm/farm.mjs", "why", str(a["id"])], 30),
    ),
    Tool(
        "list_tools_by_verdict",
        "List evaluated external tools filtered by verdict (ADOPT, STEAL-IDEAS-ONLY, IGNORE).",
        {
            "type": "object",
            "properties": {"verdict": {"type": "string", "enum": ["ADOPT", "STEAL-IDEAS-ONLY", "IGNORE"]}},
            "required": ["verdict"],
            "additionalProperties": False,
        },
        lambda a: _run(["node", "scripts/farm/farm.mjs", "list", str(a["verdict"])], 30),
    ),
]

BY_NAME = {t.name: t for t in TOOLS}


def handle(req: dict[str, Any]) -> dict[str, Any] | None:
    method, rid = req.get("method"), req.get("id")

    if method == "initialize":
        return {"jsonrpc": "2.0", "id": rid, "result": {
            "protocolVersion": PROTOCOL_VERSION,
            "capabilities": {"tools": {}},
            "serverInfo": {"name": "gm-toolkit", "version": "1.0.0"},
        }}

    if method in ("notifications/initialized", "initialized"):
        return None  # notification: no reply

    if method == "tools/list":
        return {"jsonrpc": "2.0", "id": rid, "result": {"tools": [
            {"name": t.name, "description": t.description, "inputSchema": t.schema} for t in TOOLS
        ]}}

    if method == "tools/call":
        params = req.get("params") or {}
        tool = BY_NAME.get(params.get("name", ""))
        if tool is None:
            return {"jsonrpc": "2.0", "id": rid,
                    "error": {"code": -32602, "message": f"unknown tool: {params.get('name')}"}}
        args = params.get("arguments") or {}
        for req_key in tool.schema.get("required", []):
            if req_key not in args:
                return {"jsonrpc": "2.0", "id": rid,
                        "error": {"code": -32602, "message": f"missing required argument: {req_key}"}}
        try:
            result = tool.fn(args)
        except Exception as exc:  # noqa: BLE001
            result = {"ok": False, "error": f"{type(exc).__name__}: {exc}"}
        return {"jsonrpc": "2.0", "id": rid, "result": {
            "content": [{"type": "text", "text": json.dumps(result, indent=2)}],
            "isError": not result.get("ok", False),
        }}

    if rid is None:
        return None
    return {"jsonrpc": "2.0", "id": rid, "error": {"code": -32601, "message": f"unknown method: {method}"}}


def main() -> int:
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            req = json.loads(line)
        except json.JSONDecodeError:
            continue
        resp = handle(req)
        if resp is not None:
            sys.stdout.write(json.dumps(resp) + "\n")
            sys.stdout.flush()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
