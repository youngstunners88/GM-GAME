#!/usr/bin/env python3
"""Task router — classify a task, then emit the tier / manifest / skills / gates for it.

Engine is Jev via pijev (TypeLLM). Jev is a calibrated option-picker: it returns a
probability per class rather than prose, which is exactly the shape of a routing
decision and costs a fraction of asking a frontier model to reason about its own tier.
pijev averages over several option orderings so the answer does not depend on the
order we happen to list the classes in.

Separation of concerns, deliberately:
  - routes.json  owns WHAT the classes are         (declarative, reviewed in PRs)
  - this file    owns HOW a task maps to one       (mechanism)
  - Jev          owns the judgement call           (swappable)
Change routing policy by editing routes.json; you should not need to touch this file.

Fails SOFT: no key, no network, or a bad answer -> routes.default_class. A router that
crashes is worse than a router that is conservative, so the fallback is the safest
class (opus + full manifest), never the cheapest.
"""
from __future__ import annotations

import argparse
import json
import os
import sys
from dataclasses import dataclass, asdict
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
ROUTES = ROOT / "tools" / "farm" / "routes.json"
KEY_VARS = ("TYPESAFE_API", "TYPESAFE_API_KEY")


@dataclass(frozen=True)
class Decision:
    """Typed result. Frozen so a caller cannot mutate a routing decision after the fact."""
    task: str
    cls: str
    tier: str
    manifest: str
    skills: tuple[str, ...]
    gates: tuple[str, ...]
    confidence: float
    engine: str          # "jev" | "fallback"
    note: str = ""

    def to_json(self) -> str:
        d = asdict(self)
        d["skills"] = list(self.skills)
        d["gates"] = list(self.gates)
        return json.dumps(d, indent=2)


def load_routes() -> dict[str, Any]:
    try:
        return json.loads(ROUTES.read_text())
    except Exception as exc:  # noqa: BLE001
        print(f"FATAL: cannot read {ROUTES}: {exc}", file=sys.stderr)
        raise SystemExit(2) from exc


def api_key() -> str | None:
    for v in KEY_VARS:
        if os.environ.get(v):
            return os.environ[v]
    return None


def build(routes: dict[str, Any], task: str, cls: str, conf: float, engine: str, note: str = "") -> Decision:
    classes = routes["classes"]
    if cls not in classes:                      # Jev returned something unexpected
        cls, note = routes["default_class"], f"unknown class from engine; fell back. {note}".strip()
        engine = "fallback"
    c = classes[cls]
    return Decision(
        task=task, cls=cls, tier=c["tier"], manifest=c["manifest"],
        skills=tuple(c.get("skills", ())), gates=tuple(c.get("gates", ())),
        confidence=conf, engine=engine, note=note,
    )


def classify(task: str, routes: dict[str, Any], permutations: int = 8) -> Decision:
    key = api_key()
    if not key:
        return build(routes, task, routes["default_class"], 0.0, "fallback",
                     note=f"no API key in {'/'.join(KEY_VARS)}; routed to safest class")
    try:
        import pijev
    except ImportError:
        return build(routes, task, routes["default_class"], 0.0, "fallback",
                     note="pijev not installed (pip install pijev); routed to safest class")

    criteria = {name: c["describe"] for name, c in routes["classes"].items()
                if name != routes["default_class"]}
    client = None
    try:
        client = pijev.TypeSafeClient(api_key=key, n_permutations=permutations)
        resp = client.system_one(
            state={"task": task},
            questions={"klass": pijev.Choice(
                instructions=(
                    "Classify this software task for a Godot 4.3 game repository so it can be "
                    "routed to the cheapest model that will still get it right. Prefer a cheaper "
                    "class only when the task is genuinely routine."),
                criteria=criteria)},
        )
        ans = resp.answers["klass"]
        return build(routes, task, ans.choice, float(ans.confidence), "jev")
    except Exception as exc:  # noqa: BLE001
        return build(routes, task, routes["default_class"], 0.0, "fallback",
                     note=f"engine error: {type(exc).__name__}; routed to safest class")
    finally:
        if client is not None:
            try:
                client.close()
            except Exception:  # noqa: BLE001, S110
                pass


def main() -> int:
    ap = argparse.ArgumentParser(description="Route a task to a model tier and context manifest.")
    ap.add_argument("task", nargs="+", help="the task description, in plain words")
    ap.add_argument("--json", action="store_true", help="machine-readable output")
    ap.add_argument("--permutations", type=int, default=8, help="Jev option orderings to average")
    args = ap.parse_args()

    d = classify(" ".join(args.task), load_routes(), args.permutations)
    if args.json:
        print(d.to_json())
        return 0
    print(f"class      {d.cls}  ({d.engine}, confidence {d.confidence:.2f})")
    print(f"tier       {d.tier}")
    print(f"manifest   {d.manifest}")
    if d.skills:
        print(f"skills     {', '.join(d.skills)}")
    if d.gates:
        print(f"gates      {', '.join(d.gates)}")
    if d.note:
        print(f"note       {d.note}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
