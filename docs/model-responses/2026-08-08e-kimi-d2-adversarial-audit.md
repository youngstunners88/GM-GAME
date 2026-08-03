<!-- dispatched: moonshotai/kimi-k3
     prompt: /tmp/claude-0/-home-user-GM-GAME/a77cc0d7-ba64-5875-85a6-fe6f7aa41b68/scratchpad/prompts/kimi-d2-floor-audit.md
     files inlined: 3
     tokens: 16469 in / 23285 out
     cost: $0.3987
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
## Verdict up front

The API claims are correct and the fix's core approach is sound, but: **(a)** your "arbitrary/history-dependent" mechanism is wrong — the misalignment was deterministic, and the comment you wrote into the file now documents a false mechanism; **(b)** your centering math introduces a *permanent* ~290–350px blank band on the left of the screen for the entire Distributor fight. Details below.

---

## 1. Parallax mechanics — partially wrong

**API semantics: correct.** In Godot 4.3, `motion_scale = Vector2(1, 1)` makes a `ParallaxLayer` translate 1:1 with the camera (it's the default and is world-locked), and `motion_mirroring = Vector2.ZERO` disables repeat per-axis — zero is the correct "off" value, no sentinel needed. Both assumptions hold.

**The "arbitrary/history-dependent" claim: wrong.** Parallax offset is a pure function of camera scroll position. Nothing accumulates; `motion_offset` and `scroll_offset` are never written anywhere. For a given standing position in the arena the offset is reproducible, and it was a *fixed* offset, not drift:

- Camera Y is clamped: `limit_bottom = kill_zone_y + 100 = 950` → camera center Y ≤ 590 while the player stands on the arena floor. Canvas scroll Y = 230. Old vertical offset: art floor row 605 rendered at screen `605 − 230×0.5 = 490`; real ground (world 650) at screen `650 − 230 = 420`. **A constant 70px float.** That matches the founder's screenshot exactly, but it would reproduce identically every time.
- Horizontal: camera X = 3760 in the arena (limit_right 4400 → center max 3760), scroll 3120, ×0.35 = 1092 → a mirrored seam at a fixed screen x ≈ 188. Also deterministic.

The only "inconsistency" was swimming while the camera moved (0.35×/0.5× rate). "Differs based on how the player got there — walked, respawned, Blaze Rush return" is not a real effect of this system. (Respawn may genuinely change what the player sees — but via scene reload resetting the backdrop to the normal art until the trigger re-fires, not via parallax state.) Since the fix bakes this false mechanism into a large comment block above `BOSS_ART_FLOOR_ROW`, rewrite it: the next person debugging a regression here will chase a nonexistent state-accumulation bug.

## 2. Simpler explanations — checked, ruled out, with one caveat

- **Camera behavior can't produce this symptom class.** Camera limits/follow translate backdrop art and world geometry *together* on screen. Only a differential `motion_scale` can create a *relative* offset between the two. So your parallax theory isn't just plausible, it's the only mechanism in the provided code that can produce "floats relative to the art but collision works."
- **Distributor hover:** boss-side and intentional (`HOVER_RISE = 180`, anchored from spawn). The report is about Lil Blunt, not the boss. Ruled out.
- **Player collision shape vs. sprite:** would make him float on *every* platform in the level, not specifically "near the Distributor boss arena." The arena-localized symptom matches the only arena-specific visual system: the backdrop swap.
- **Caveat / missing file:** the Level 2 subclass that overrides `_on_boss_trigger()` was not provided. I'm assuming it calls `set_boss_background()`. Since the founder described boss art, it evidently does — but if the audit is meant to be exhaustive, that call site and its timing are unverified.

## 3. L1/L3 regression risk — real, and currently unverifiable

- `BOSS_ART_FLOOR_ROW = 605.0` is a property of one specific painting. The Auditor's and Claim Jumper's boss arts will have their own walkway rows; a shared constant misaligns them by exactly the row difference. **Missing:** `level_01_data.tres`, `level_03_data.tres`, and the actual JPGs — I can't tell you their floor rows. This constant should move into `LevelData` (e.g., `boss_art_floor_row` export) with per-level values. **Missing:** `level_data.gd`, so I can't confirm what fields exist.
- The coverage-hole math in section 4 below applies to L1/L3 too, scaled by their arena widths and camera clamps — also unverifiable without their `.tres` files.
- If either of their arts was authored to *tile* horizontally (relying on the old mirroring), zeroing mirroring now exposes blank edges. Check before shipping.

## 4. Bugs in the GDScript

**B1 (the real one): the fix creates a permanent blank strip on the left third of the screen for the whole fight.**
Art placement: `(3700+4400)/2 − 640 = 3410` → the diorama covers world x ∈ [3410, 4690]. But the camera is clamped to center-x ≤ 3760 (`limit_right = 4400`, viewport 1280), so the view's left edge is **always** ≤ 3120 < 3410. Uncovered strip = `3410 − view_left` ∈ **[290px, 350px]** for the entire sealed fight, wider at the moment of the trigger crossing. The old setup tiled infinitely, so this hole is new. Note the arena (700px) is narrower than the viewport (1280px), so "center the art on the arena" was the wrong target: the fight plays on the right side of a clamped view, and covering the *camera's reachable range* [3060, 4400] would need 1340px of art — the image is 60px too short even with optimal placement. Cleanest fix: during the fight pin the camera (`cam.limit_left = end_x − 1280 = 3120`, giving a fixed view [3120, 4400]) and anchor the art's west edge to 3120. Alternative: scale the sprite up ~4.7%.

**B2: `layer.position = Vector2.ZERO` is dead code.** `ParallaxBackground` rewrites `ParallaxLayer.position` on every camera-moved update; the persistent-offset API is `motion_offset` (which was never non-zero anyway). Harmless, but delete it — it misdocuments how the node works.

**B3: one-frame stale layout.** `ParallaxBackground` re-lays out on camera movement; if the camera happened to be stationary the frame the trigger fires, the layer renders one frame at its old 0.35-scale position. In practice the player is moving when crossing the trigger. Trivial.

**B4: `_floor_y_at` fallback is silent.** Right-exclusive `x < seg.x + seg.z` is correct here (start_x = 3700 hits the last segment → 650 ✓), and sampling at `start_x` is fine for L2's flat arena. But the level is full of segment gaps (e.g., x = 450); if any level's `start_x` ever lands in one, the fallback returns `kill_zone_y` (850) and the walkway sits 200px below the real floor with no warning. Add a `push_warning` in the fallback branch.

**B5: post-death backdrop state is undetermined.** If death respawns in place (no scene reload), the swap has destroyed the normal backdrop for the *entire level west of x=3410* — walking back from a checkpoint means a void behind the level. If death reloads the scene (the `_spawn_player` checkpoint path suggests it does), this is moot: fresh backdrop, trigger re-fires. **Missing:** `player.gd` (`pit_death`/`die`) and the `GameManager` respawn flow — can't resolve which.

**Not bugs (verified):** vertical sign is correct — sprite top = `floor_y − 605` with `centered = false` puts art row 605 exactly at world 650, coincident with the platform lip (650–654 per `_create_platform`). Centering arithmetic is exact, no off-by-one, `/2.0` avoids integer division. Variant→`float` assignments from the `boss_arena` Dictionary convert cleanly. Null checks and `is_instance_valid` are adequate. Minor comment rot: `_backdrop_sprites` is documented as "three parallax sprites (far/mid/near)" but `_setup_background` appends exactly one.

**Bottom line:** right root cause (misdescribed), right mechanism for the fix, but B1 ships a new, always-visible visual defect in the exact arena you were fixing — fix the placement target before this goes out.