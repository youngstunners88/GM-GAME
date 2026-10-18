# Rich's Armory lock — release verification (2026-10-18)

Build **`2026-10-18-cb000a4`** · source `cb000a45` · CI run [39089930801](https://github.com/youngstunners88/GM-GAME/actions/runs/39089930801)

## What shipped

The `feat/rich-armory-lock` branch (11 commits) merged to master and deployed:

- **Rich's Armory** — own building off Main Street (side lane, off the sightline), operator Rich + partner Utah on first visit; crypto-only trade (Episode 1 BTC/ETH/SOL), 1800s firearms/ammunition/accessories including the period long rifle; river gear source for the day-88 set-piece. Personal armory systems untouched.
- **Folk people rebuilt** — `rich_armory.glb` / `utah_armory.glb` re-exported (material-slot dedupe, sparse authored keys, `export_optimize_animation_keep_anim_armature`) and validated (20 bones + 5 named clips each, poses matched to the previously shipped GLBs).
- **Pack fixes** — the three below.

## Pack gate

| measure | bytes |
|---|---|
| gate (190 MiB) | 199,229,440 |
| before this work (fresh clone) | 199,772,880 — **543,440 over** |
| after (fresh clone, ship gate) | 191,801,072 |
| CI export of `cb000a45` | **191,800,848** — 7.43 MB under |

Fixes: (1) 20 loose Meshy/Tripo texture exports excluded from the export preset (~7.8 MB — GLBs embed their textures, zero references, no runtime dir-scan covers those folders); (2) `sign_ARMS.png` re-imported at the sibling-sign preset (144,584 → 8,494 B); (3) folk GLB rebuild (~22.5 KB of pck, done for asset hygiene). Findings: `docs/episode2-quality/3d-tools-survey-2026-10-17/README.md` §4.

## CI gates (run 39089930801, conclusion success)

- `EP2_GOLD_TOWN: ALL PASS` (64 checks incl. the 18 Armory checks)
- `EP2_PERSONAL_ARMORY`, `EP2_CHARACTER_MOTION`, `EP2_BOW`, `EP2_COMPANION_CART: ALL PASS`
- all other headless gates pass (pause tap-target machine difference tolerated as before)
- security sentinel 18/18, 0 blockers

## Live proof

- Served pack at the **new** embed key `18305533-2150280` (`/html/…/index.pck`, last-modified 2026-10-18 02:54:54 UTC): **191,800,848 B**, contains `2026-10-18-cb000a4`.
- Served `index.html` byte-identical to the CI-committed `web/game/index.html` except itch's standard trailing `htmlgame.js` injection.
- Headless Chromium boot of the live embed: `[BUILD] Lil Blunt Adventure — build 2026-10-18-cb000a4`, zero script errors; title screen captured → `live-title-2026-10-18-cb000a4.png`. Title lock preserved.
- Button-fix note for future deploy proofs: itch creates a **new embed key per build**; the old key keeps serving the old files. Read the current embed `src` from the page's `data-iframe` attribute.

## Boundaries (honest)

- No protected playthrough on the public page (access gate preserved); armory gameplay verified by the CI headless gates + the session's own test runs.
- No voice pass (no voice key on this box; lines recorded in `RICH_UTAH_LINES.md`).
- Day-88 river set-piece is designed but not built.
