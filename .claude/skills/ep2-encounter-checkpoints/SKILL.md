---
name: ep2-encounter-checkpoints
description: Make woods and quad combat fail/retry at the surface elevator exit with atomic restoration of finite ammo, companion state, bear bodies and loot, and reproducible varied encounters. Use for encounter death, checkpoint saves, retry exploits, state ownership or seeded outcomes.
---

# Surface exit checkpoint

Read design/ep2/LIVING_WOODS_CONTRACT.md. Inspect Ep2SessionRoot, current run/session state, Ep2Interlude, save migration and chamber_failed handling. Reuse existing ownership and access gates; proposed checkpoint interfaces are not implemented yet.

## Capture and failure contract

- Capture hideout_surface_exit once both protagonists leave the shaft onto solid surface ground and before woods danger. Preserve legitimately earned Winchester/golden Remington and acquisition facts.
- Keep the player's single health owner and three-heart cap. Companion incapacitation is a terminal encounter condition, not a second player health system or a permanent story death.
- All failed attempts in this requested escape slice restart here, including quad pursuit. Do not replay range/lava/lift, auto-save after mounting, or secretly change the recovery point to the ridge.
- Snapshot player/Bull transforms and navigation, health/readiness, armory selection and ammo/arrows, bear IDs/routines/death records, loot claims/projectiles, camouflage/quad, objective/chain progress, world seed and camera/audio ownership.
- On first failure, freeze active input/damage/AI, mark the attempt terminal, cancel scripted waits/timers and pending loot/projectile transactions, then restore as one transaction and start exactly one simulation. Duplicate death events are no-ops. Display a concise cause and Retry from surface exit.
- Restore failed-attempt loot, spent ammunition and dead bears together. Retaining looted arrows while reviving their source bear is forbidden. Revisit/save/load are idempotent. Before-checkpoint accomplishments survive.
- For non-linear outcomes vary bounded routine offsets/reaction delays/local arrival order with an explicit attempt seed; retain fixed checkpoint identities and drop contents. Log seed + inputs for reproduction. Retry variation cannot reroll better loot or spawn instant unfair crowds.
- If saving persistent games, version checkpoint schema, validate required fields, migrate prior saves and handle interrupted/corrupt restoration without an inconsistent half-world.

## Required evidence for implementation

Proposed future gate ep2_escape_checkpoint_test: player and companion failure; repeated failure callbacks; retry while reloading/looting/mounting/brushing; inventory/corpse digest conservation; room revisit/save-load; objective/music/input reset; no surviving old shooters; earned acquisition migration; same-seed reproduction and differing bounded seeds; no post-checkpoint loot retention. These tests do not exist yet.

Run quiet, detected-on-foot, defensive-fire, noisy-ride, fail/retry and delayed-lookout pursuit scenarios with recorded inputs/seeds. Require meaningful outcomes: quiet can succeed; alert can be survived; bears can die and be searched; a real failed attempt retries. Do not replace this with a syntax check or a zero-test run.
Preserve existing tests/ep2_session_root_test.tscn, ep2_interlude_test.tscn, save_compat_test.tscn and Fort Knox gates. Capture player-visible cause/retry and the same restored armory/bodies at the surface point.
