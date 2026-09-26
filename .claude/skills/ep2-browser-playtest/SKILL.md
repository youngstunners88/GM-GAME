---
name: ep2-browser-playtest
description: Prove an Episode 2 change in the REAL web build — local export with CI's exact preset, then drive the runner in Chromium by track distance with keys, mouse aim and clicks, and screenshot each beat. Use after any Episode 2 gameplay or visual change, before saying it works, and to make the founder's screenshots.
---

# Episode 2 browser playtest

```bash
bash scripts/ep2-local-export.sh          # CI-identical export into web_verify/, served on :8899
npm install --no-save playwright@1        # once per container
node scripts/ep2-play.mjs .farm/shots '<plan>' [extra-query]
```

`?ep2probe=1` makes the game print `[EP2] d=<metres> hp=<health>` and `[EP2] leg start N`, so the
harness acts on **track distance**, not wall-clock (the CPU-rendered browser here runs the sim at
~⅓ speed; timed inputs land in the wrong place). Extra queries: `ep2leg=1` starts on leg 2,
`ep2chamber=1` shortens leg 1 to reach Chamber 0 fast.

Plan steps (JSON array, in distance order):
`{"leg":0,"d":60,"key":"Space"}` · `{"down":"KeyS"}` / `{"up":"KeyS"}` · `{"move":[x,y]}` (aim) ·
`{"click":[x,y]}` (LMB fire at that screen point) · `{"rclick":[x,y]}` (pickaxe) ·
`{"key":"KeyR"}` (reload) · `{"shot":"name"}` (screenshot).

The run prints every health loss (`HIT at leg L d=…`) and the final leg/d/hp.

## Rules that keep the proof honest

- **A screenshot costs ~2 s of sim time.** Never put one just before an input — the input lands
  late and you "find" a bug that isn't there. Prove survivability with a screenshot-free run;
  capture pictures in a separate run.
- The export must be fresh: the script deletes the old pck and fails if none is produced. An
  "exit 1" export with an old pck still on disk once passed a stale build off as the new one.
- Console noise that is NOT ours: `Failed to fetch` / `ERR_CERT_AUTHORITY_INVALID` (price APIs
  blocked by this sandbox's proxy), `MENU → MENU` state warning. Anything else is real.
