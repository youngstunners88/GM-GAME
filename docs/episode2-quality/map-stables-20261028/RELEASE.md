# Western chart and stables departure — 2026-10-28

Founder brief read through Drive: `PROMPT_EPISODE2_MAP_AND_STABLES_RIDE_CODEX_2026-10-28.md`, file `11rOJL7x_ZiSw64-Md4rzIRny218Y6qQ4`.

P pauses/resumes both episodes. Removed the added desktop pause HUD button completely; Save has FOCUS_NONE so Space cannot activate it after a mouse click. Existing touch pause remains. Escape compatibility remains.

Loot sets persistent `has_region_map` and auction destination. The shared Episode2 chart survives handoffs; M toggles its own pause and Escape closes it before ordinary pause. It cannot steal another modal's pause. Touch uses the chart itself and the close icon, with no key labels. Hand-authored parchment art is reproducible via `tools/ep2_map/build_map.py`. The map is a schematic, with approximate distances and room-relative player marker; it does not invent a new traversable auction or river route.

After Dude's original lake directions an additional caption explicitly says mount here. Existing recordings remain unchanged; the additional caption has no invented voice recording. The horse purchase marks Logan's Lake. GEARED prebuilds the trail but never departs automatically. E within3m of stable horse1 mounts; player position and eye rise interpolate over1.2s. The trail begins in the same ranch set (coordinates translated to trail-local origin), exits through the ranch gate and retains ambushes and lake handoff. The stationary copy of the mounted horse is hidden at the trail start.

Verification completed so far:
- Manual checkpoint suite:36 checks,0 failures, including P in both episodes and unfocusable HUD Save.
- Region map:10 checks,0 failures (ownership/destination reload, M/Escape/modal ownership/player marker). The initial hidden-before-loot check caught a visible-on-first-frame defect; the corner now starts hidden.
- Town story, lake trail, ranch, save compatibility and Episode2 touch suites pass. Updated town story test requires explicit mounting and proves no timed departure.
- Real Compatibility camera review: parchment chart, stables, midpoint mount, ranch trail start and gate exit. Captures included; the corner subsequently moved below the offline banner.
- Exported browser pause playtest: all gates pass, including physical P, movement freeze/resume, Space after mouse Save, companion/restart/quit.
- External replay of actual exported resources:5 checks pass, including physical M/Escape, world pause and explicit stable mount. This fixture does not bypass any production access control.
- Local nonthreaded Compatibility export:197399440-byte main pack,0 script errors. Fresh-import main pack:197367008 bytes,1862432 bytes below the unchanged190MiB cap. Full local CI regression suite passes (only the three established local pause/HUD geometry differences tolerated by the repository gate).
- Security Sentinel: no high blockers; title lock and harness checks pass.

Production release confirmed:
- Source `ac8e5be325d432b805886f8e07be7604d0208f8f`; CI40656596827/job122709009298 completed successfully, including full gameplay, camera captures, web export and pack checks.
- Actual butler log: “Re-used84.90% of old, added51.10MiB fresh data”; “Pushed to https://youngstunners88.itch.io/smokerealm”.
- Public BUILD `2026-10-28-ac8e5be`; extras HTTP200/ready and unchanged Episode2 access-code screen verified.
- Actual public main197366816B/extras121764320B, both below199229440B. SHA512 receipts cover the public engine and both packs.
- Direct public-origin desktop pause playtest ALL GATES PASS: P/freeze/resume, mouse Resume, companion, Space after Save, restart and quit;0 console errors.
- External fixture against exact downloaded public engine/packs:5PASS (physical M/Escape, map pause, no automatic town departure, E mount at stables). This is distinct from an authenticated public-origin Episode2 walkthrough. No physical-phone certification is claimed.

No provider spend.
