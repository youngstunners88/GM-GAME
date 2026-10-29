#!/usr/bin/env python3
"""Validate a GM-GAME release receipt's completeness, not its factual truth.

Read the actual CI/upload/public evidence before filling the receipt. This helper
cannot replace a successful deployment or a real browser check.
"""
import argparse
import json
from pathlib import Path
import re


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("receipt", type=Path)
    args = parser.parse_args()
    repo = Path(__file__).resolve().parents[1]
    receipt = json.loads(args.receipt.read_text())
    errors = []
    if not re.fullmatch(r"[0-9a-f]{40}", str(receipt.get("source_sha", ""))):
        errors.append("source_sha must be an exact commit SHA")
    build = receipt.get("build_id")
    if not isinstance(build, str) or not build or build == "dev-local":
        errors.append("build_id must be an observed public BUILD")
    if receipt.get("play_url") != "https://youngstunners88.itch.io/smokerealm":
        errors.append("play_url must be the repository's current production game")
    checks = receipt.get("checks", {})
    for key in ("export", "gameplay", "visual", "security", "deployment", "live_input"):
        if checks.get(key) is not True:
            errors.append(f"missing verified check: {key}")
    evidence = receipt.get("evidence", [])
    if not isinstance(evidence, list) or not evidence:
        errors.append("evidence must name retained files")
    else:
        for item in evidence:
            path = (repo / str(item.get("path", ""))).resolve()
            if not path.is_relative_to(repo) or not path.is_file():
                errors.append(f"missing/outside evidence: {item.get('path')}")
    deployment = receipt.get("deployment", {})
    if not re.fullmatch(r"https://github\.com/youngstunners88/GM-GAME/actions/runs/[0-9]+", str(deployment.get("run_url", ""))):
        errors.append("deployment must name the observed workflow run")
    if deployment.get("outcome") != "success" or deployment.get("deploy_step") != "success":
        errors.append("deployment and actual deploy step must succeed")
    if deployment.get("observed_build_id") != build:
        errors.append("public BUILD differs from the released BUILD")
    if receipt.get("open_blockers") != []:
        errors.append("open_blockers must be an explicitly empty list")
    print(json.dumps({"complete": not errors, "errors": errors}, indent=2))
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
