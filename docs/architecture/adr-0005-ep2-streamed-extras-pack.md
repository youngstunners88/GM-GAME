# ADR-0005: Episode 2 extras ship as a second, streamed resource pack

## Status
Accepted (2026-10-19)

## Context
The web build has a hard gate: `index.pck` <= 199,229,440 B (190 MiB), because itch rejects any single file over 200 MB. On 2026-10-19
the margin was ~0.47 MB. The founder's two-storey Armory, his Tripo Rich and Utah and their motion clips need ~4 MB of imported data.
The founder chose "Stream Episode 2 extras" over re-encoding music or shrinking the characters' textures.

## Decision
- New Episode 2 art that does not fit lives under `res://src/episode2/extras/`.
- CI's export `exclude_filter` leaves that folder out of `index.pck`; right after the export, `tools/ep2_extras/pack_extras.gd`
  (PCKPacker, same Godot 4.3) packs the folder's imported data - each `.import` remap plus every `dest_files` entry, the way an export
  would - into `web/game/ep2_extras.pck`, which butler deploys beside `index.pck`.
- `Ep2Extras` (`src/episode2/ep2_extras.gd`) starts an `HTTPRequest` download of `ep2_extras.pck?v=<BUILD_TAG>` into `user://` when
  Episode 2's entry scene loads, and mounts it with `ProjectSettings.load_resource_pack`. Off the web (editor, tests, desktop) the
  files are on disk and nothing downloads.
- Every caller checks `Ep2Extras.has(path)` and keeps its old asset as the fallback (the town draws the one-storey Armory and the old
  Rich and Utah until the pack is mounted), so a slow or failed download never removes content.

## Consequences
- `index.pck` stays under its gate; the extras pack has its own per-file check in CI (< 190 MiB).
- Scripts stay in `index.pck` (only art goes in extras), so class names resolve before the pack mounts.
- The extras' `.import` files must be in Godot 4.3's own format (tracked, force-added) or CI's import dirties the tree and its
  bookkeeping commit fails (2026-10-18 incident).
- `tools/ep2_forge/texture_ref_probe.gd` allows literal `res://src/episode2/extras/` paths (excluded on purpose).
- A player who reaches the town before the download completes sees the old Armory for that visit.

## ADR Dependencies
None (extends the export pipeline in `.github/workflows/export-game.yml`).

## Engine Compatibility
Godot 4.3 (pinned for CI/export): `PCKPacker`, `ProjectSettings.load_resource_pack(pack, replace_files, offset)`, `HTTPRequest.download_file`,
`JavaScriptBridge.eval` with a literal string (security-sentinel INJ-003 form (a)). Verified: an empty 4.3 project mounts the pack and
loads all three scenes; the real web export downloads and mounts it in Chromium.

## GDD Requirements Addressed
Founder brief 2026-10-19 (two-storey Armory, Rich and Utah working in it) under the 190 MiB web pack gate.
