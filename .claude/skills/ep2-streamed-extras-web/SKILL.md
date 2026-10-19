---
name: ep2-streamed-extras-web
description: Make the streamed Episode 2 extras pack (ep2_extras.pck - the two-storey Armory, the town kit with real windows/doors, the townspeople) actually load on itch.io. The CDN gzips it, which breaks Godot 4.3's web HTTPRequest; the pack must come from a browser fetch() + Engine.copyToFS, and every change is proven behind tools/ep2_extras/gzip_server.py and then on the live game. TRIGGER on "[EP2] extras failed", "the new town/armory doesn't show", "err != 0 && err != 1", editing src/episode2/ep2_extras.gd, adding anything under src/episode2/extras/, or before shipping a change to the streamed pack.
---

# Streamed Episode 2 extras on the web (ADR-0005; incident 2026-10-19/20)

## The fault (proven, do not re-learn)
itch's CDN (`html-classic.itch.zone`) gzips `ep2_extras.pck` when the request accepts gzip (every browser does) and sends
`Content-Length` = the COMPRESSED size (5,036,892 B for a 5,037,408 B file). The browser hands the engine the decoded bytes, Godot
4.3's web HTTPClient sees more body than Content-Length and fails: `USER ERROR: Condition "err != 0 && err != 1"` ->
`[EP2] extras failed (http 200)`. Players got the new build but none of the streamed art.
- A `curl -I` WITHOUT `Accept-Encoding` shows no gzip - that is why one check wrongly ruled it out. Always test as a browser:
  `curl -s -D - -o /dev/null -H "Accept-Encoding: gzip, deflate, br" <url>`.
- Reproduction that matched the live error exactly: the live build mirrored locally, served plainly -> `extras ready`; served by
  `tools/ep2_extras/gzip_server.py` (gzip + compressed Content-Length) -> the live failure line.

## The fix (src/episode2/ep2_extras.gd)
- No `HTTPRequest` for packs on the web. A literal `JavaScriptBridge.eval` (security-sentinel INJ-003 form (a); values passed through
  `window.__ep2x_*`, never interpolated) runs `fetch(base + 'ep2_extras.pck?v=' + tag)` -> `arrayBuffer()` ->
  `engine.copyToFS(path, buffer)` (Godot 4.3's public `Engine.copyToFS`; `engine` is the shell's global; GodotFS.copy_to_fs makes the
  folder) at `ProjectSettings.globalize_path("user://ep2_extras.pck")`; GDScript polls `window.__ep2x_state` and mounts with
  `ProjectSettings.load_resource_pack`. "ready" is printed only after the mount AND `ResourceLoader.exists(Ep2Extras.ARMORY)`.
- Callers keep their fallback (`Ep2Extras.has()`): a failed download shows the old art, never a hole.

## Proof before any ship (all three)
1. `bash scripts/ep2-local-export.sh` (pinned 4.3 export + packs the extras) then `bash scripts/extras-gzip-check.sh` -> must print
   `PASS extras log says ready` under the itch-style gzip server.
2. Town gates: `ep2_town_people_test`, `ep2_armory_two_story_test`, `ep2_gold_town_test`; `scripts/security-sentinel.sh` 0 blockers.
3. After the founder ships and CI deploys: `node scripts/live-itch-probe.mjs --expect <master sha7> --extras` exits 0 (skill
   `live-itch-terminal-proof`). Only then say the town is live.

## Do not
- Do not call a browser agent's or a local plain-server result proof for itch. Only the gzip server and the live probe count.
- Do not move big art back into `index.pck` to dodge this; the 190 MiB gate is ~0.4 MB from full.
