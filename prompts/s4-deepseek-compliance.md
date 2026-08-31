Role: COMPLIANCE MATRIX, built BEFORE implementation as a falsifiable
pre-flight checklist (every item NOT STARTED). Be strict — say what PROOF each
item needs, not "code touched". A Godot 4.3 2D platformer.

Founder prompt + shared facts:
@include docs/founder-prompts/PROMPT_VAULTS_FULL_ENV_LIKE_BLAZE_BOSSES_HAMMER.md
@include prompts/_s4_facts.md

Table: Item | What the prompt requires | Falsifiable proof it's actually done |
Status (NOT STARTED).

Cover, at minimum:
- **Vault = full environment (not a pit).** What automated/observable check
  distinguishes "loaded a separate scene with its own backdrop and a return
  path" from "an in-level pit"? (e.g. entering triggers a SceneRouter scene
  change to a distinct .tscn; the vault scene is NOT a child of the level;
  exiting returns to the origin level at the entry position.) The founder has
  rejected the pit twice — this check must make "another pit with a paint job"
  impossible to pass.
- **Diamond stake loop present + readable.** What proves a real stake action
  exists and touches the real GoldMineSystem primitives (not a cosmetic
  animation)?
- **Exit resumes stage at entry region.** Falsifiable position check.
- **T3 S2 boss chases + fires VISUALLY DISTINCT crystals in the REAL arena.**
  Prior headless gates passed while the founder saw it broken — what makes THIS
  pass's proof trustworthy? Note the category of live-only bug a headless gate
  cannot catch and flag it honestly.
- **T4 S3 boss: real explosion damage, faces the player, pursues horizontally
  past the freeze.** Falsifiable checks for each of the three.
- **T5 hammer works** — but note it can't be gated until the vision model
  identifies which tool "the hammer" is; flag that dependency.
- **T6 S3 death respawns near death**, not a cross-level default. Falsifiable
  position check.
- Process: multi-model log present; gates green; build id live; web export
  non-threaded; no soft-lock.

Concise table + short notes. Confirm the KEEP/out-of-scope items (Episode 2,
video, legal, DeFi enable) are NOT in scope so they don't get flagged.
