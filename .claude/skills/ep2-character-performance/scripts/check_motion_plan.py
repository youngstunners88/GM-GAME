#!/usr/bin/env python3
"""Validate a motion job's inputs; never certify animation/contact/runtime output."""
import argparse
import hashlib
import json
import math
from pathlib import Path


def check(plan, repo):
    errors, pending = [], []

    def need(ok, message):
        if not ok:
            errors.append(message)

    def path(value, label, optional=False):
        if not value and optional:
            pending.append(label + " is unresolved")
            return None
        if not isinstance(value, str):
            errors.append(label + " must be a relative path")
            return None
        p = (repo / value).resolve()
        if Path(value).is_absolute() or not p.is_relative_to(repo):
            errors.append(label + " must stay inside the repository")
            return None
        if not p.is_file():
            errors.append(label + " does not exist: " + value)
            return None
        return p

    def number(value):
        return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value)

    need(plan.get("schema") == "gm-game.character-motion-plan.v1", "unsupported schema")
    need(plan.get("status") in ("draft", "ready"), "status must be draft or ready")
    need(isinstance(plan.get("job_id"), str) and bool(plan.get("job_id")), "job_id is required")
    sha = plan.get("source_commit", "")
    need(isinstance(sha, str) and len(sha) == 40 and all(c in "0123456789abcdef" for c in sha), "source_commit must be a full SHA")
    transcript = plan.get("transcript", {})
    source = path(transcript.get("path"), "transcript")
    if source:
        need(hashlib.sha512(source.read_bytes()).hexdigest() == transcript.get("sha512"), "transcript hash mismatch")
    appearance = plan.get("appearance", {})
    path(appearance.get("model_path"), "character model")
    path(appearance.get("reference_path"), "appearance reference")
    need(bool(appearance.get("identity_description")), "global identity description is required")
    perf = plan.get("performance", {})
    need(perf.get("method") in ("existing-clip", "blender-authored", "owner-performance", "licensed-mocap", "generated-guide"), "unsupported performance method")
    path(perf.get("source_path"), "performance source", optional=True)
    need(number(perf.get("fps")) and perf["fps"] > 0, "fps must be finite and positive")
    overlap = perf.get("overlap_frames")
    need(isinstance(overlap, int) and not isinstance(overlap, bool) and overlap >= 0, "overlap_frames must be a non-negative integer")
    need(perf.get("root_motion_owner") in ("room-in-place", "clip-root"), "declare exactly one root-motion owner")
    if perf.get("rights_status") not in ("verified", "owner-authored"):
        pending.append("performance rights are unresolved")
    audio = perf.get("audio", {})
    need(type(audio.get("preserve_soundtrack")) is bool and type(audio.get("condition_generation")) is bool, "audio preservation and conditioning must be separate booleans")
    clip = plan.get("clip", {})
    duration = clip.get("duration_s")
    if duration is None:
        pending.append("clip duration is unresolved")
    else:
        need(number(duration) and duration > 0, "clip duration must be positive")

    def interval(item, label):
        a, b = item.get("start_s"), item.get("end_s")
        if a is None or b is None:
            pending.append(label + " timing is unresolved")
            return
        valid = number(a) and number(b) and 0 <= a < b
        need(valid, label + " interval must satisfy 0 <= start < end")
        if valid and number(duration):
            need(b <= duration, label + " exceeds clip duration")

    phases = clip.get("phases", [])
    need(isinstance(phases, list) and bool(phases), "phase list is required")
    previous_end = None
    for i, phase in enumerate(phases):
        interval(phase, "phase " + str(i))
        a, b = phase.get("start_s"), phase.get("end_s")
        if number(a) and number(previous_end):
            need(a >= previous_end, "phases are out of order or overlap")
        previous_end = b
    contacts = clip.get("contacts", [])
    need(isinstance(contacts, list) and bool(contacts), "independent contact list is required")
    for i, contact in enumerate(contacts):
        label = "contact " + str(i)
        need(bool(contact.get("character_anchor")) and bool(contact.get("prop_anchor")), label + " needs two independent named anchors")
        path(contact.get("prop_path"), label + " prop")
        interval(contact, label)
        gap = contact.get("max_gap_m")
        need(number(gap) and gap > 0, label + " tolerance must be positive metres")
        if contact.get("status") not in ("authored", "verified"):
            pending.append(label + " anchors/feasibility are unresolved")
    for i, event in enumerate(clip.get("events", [])):
        t = event.get("time_s")
        need(event.get("one_shot") is True, "release events must declare one-shot ownership")
        if t is None:
            pending.append("event " + str(i) + " timing is unresolved")
        else:
            need(number(t) and t >= 0 and (not number(duration) or t <= duration), "event is outside clip duration")
    captures = plan.get("captures", {})
    need(bool(captures.get("player_camera")), "production camera is required")
    need(set(captures.get("diagnostic_views", [])) >= {"front", "side", "back"}, "diagnostic views need front/side/back")
    need(captures.get("timed_sequence_required") is True, "motion needs a timed sequence, not a still")
    need(captures.get("source_sha_and_hashes_required") is True, "capture provenance is required")
    if plan.get("status") == "ready" and pending:
        errors.append("a ready plan cannot contain unresolved inputs")
    return errors, pending


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("job", type=Path)
    parser.add_argument("--repo", type=Path, default=Path.cwd())
    parser.add_argument("--require-ready", action="store_true")
    args = parser.parse_args()
    try:
        plan = json.loads(args.job.read_text())
        errors, pending = check(plan, args.repo.resolve())
    except (OSError, ValueError, TypeError, AttributeError, KeyError) as error:
        errors, pending = ["invalid plan: " + str(error)], []
    result = {"plan_valid": not errors, "input_ready": not errors and not pending,
              "runtime_verified": False, "errors": errors, "pending_inputs": pending}
    print(json.dumps(result, indent=2))
    return 1 if errors else 2 if args.require_ready and pending else 0


if __name__ == "__main__":
    raise SystemExit(main())
