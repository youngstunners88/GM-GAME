# Game Design Document — v1.2 "BLUNT FORCE"
### Side-Scrolling Shooter Expansion for *Lil Blunt: The Smoke Realm*

**Status:** Design approved for prototype · **Depends on:** v1.0 campaign complete
**Owner:** youngstunners88 · **Doc version:** 1.0 (2026-07-26)
**Anti-pattern guard:** must NOT break v1.0 platformer mechanics (roadmap rule).

---

## PAGE 1 — CONCEPT, PILLARS, AND THE WEAPON

### 1.1 Premise
Lil Blunt finally goes home. The Smoke Realm was exile; his home planet is
**occupied** — the Compliance Authority has terraformed the cannabis forests
into audit zones. He arrives in a burning drop-pod with nothing but a
retrofitted bong and very strong opinions about paperwork.

Tonally this stays **chill-under-fire**: Lil Blunt is never aggressive for its
own sake. He's defending a home, and he's relaxed about it. Enemies are
bureaucratic machines, never people, never weed-themed (project rule).

### 1.2 Design pillars
1. **It must read as a shooter, not a platformer with a gun.** The moment-to-
   moment loop is *aim → commit → take cover → reposition*, not *jump → land*.
   If a room can be beaten by jumping past everything, the room is wrong.
2. **Cover is the verb.** Every encounter is designed around a piece of cover
   that will not survive the encounter. Cover breaking is the pacing clock.
3. **Ammo is earned in the other game mode.** Weed leaves collected in
   platformer levels are Bong Blaster ammo. This makes v1.0 content *more*
   valuable when v1.2 ships instead of obsoleting it.
4. **No wallet gate, ever.** Shooter levels unlock from campaign completion
   only. Token holders get cosmetic/spectacle flourishes, never ammo or damage.

### 1.3 The Bong Blaster — 4 upgrade tiers
Ammo is a shared pool (`bong_ammo`), spent per shot, refilled by leaves.

| Tier | Name | Behaviour | Ammo/shot | Unlock |
|---|---|---|---|---|
| 1 | **Single Toke** | One smoke bolt, short range, fast recovery. Reliable. | 1 | Default |
| 2 | **Double Barrel** | 2-bolt spread (±12°). Rewards close range, punishes sniping. | 2 | Level 4 clear |
| 3 | **Homing Haze** | Slow smoke missiles, gentle tracking. Good vs. flyers, weak vs. armor. | 3 | Level 5 clear |
| 4 | **Bong Beam** | Continuous beam, melts armor. **Overheats** — 2s fire, 3s cooldown; overheat locks the weapon and vents smoke (a readable tell). | 4/sec | Level 6 mid |

**Design intent:** every tier is a *trade*, not a strict upgrade — the same
lesson learned from the Big Mode bug in v1.0 (a "power-up" that removes
ability is a downgrade). Tier 4 has the highest DPS and the worst uptime.

**Recoil/feel spec:** each shot applies a small backward impulse (12px/s) and
0.06s of screen-shake at low magnitude. Firing while airborne halves recoil so
it never fights platforming carried over from v1.0.

---

## PAGE 2 — COMBAT SYSTEMS, ENEMIES, BOSS

### 2.1 Cover system
Cover is a `StaticBody2D` with HP, a damage state, and a **duck zone**.

- **Press DOWN inside a duck zone** → Lil Blunt crouches behind cover. While
  ducked: incoming projectiles from the covered side are absorbed by the cover
  (cover takes the damage, not the player), player movement is locked, and the
  player can *peek-fire* by pressing ATTACK (stands for 0.4s, then re-ducks).
- **Cover HP:** crates 40 · crystal formations 90 · citadel consoles 60.
- **Damage states:** 100–66% intact · 65–33% cracked (visible chunks gone) ·
  32–1% critical (shaking, particles) · 0 destroyed (shatter + dust).
- **Rule:** every arena has *exactly enough* cover to survive it if used well,
  and not enough to camp one spot. Cover destruction forces movement — that IS
  the encounter's rhythm.

### 2.2 Enemy roster
All three follow the same state machine — **patrol → alert → attack → reposition
→ (recover)** — with different parameters. Line-of-sight via raycast; no
enemy shoots what it cannot see (fair-telegraph rule from the corrections brief).

| Enemy | HP | Behaviour | Counter |
|---|---|---|---|
| **Tax Drone** | 20 | Flies a lazy patrol. On alert, hovers to a firing altitude and drops **audit papers** — slow area-denial projectiles that linger 2s as a damage field. Never rushes. | Homing Haze, or shoot it during its 0.8s drop wind-up |
| **Crystal Turret** | 120 (front) / 30 (back) | Stationary, heavy suppressing fire in a 90° arc, 1.2s telegraph flash before each burst. **Weak spot on the back.** | Flank via cover-hopping; Bong Beam melts the front if you have uptime |
| **Bandit Raider** | 45 | Fast flanker. Sprints between cover, throws **TNT** with a visible arc + 1.5s fuse, retreats when its own cover breaks. | Double Barrel at close range; destroy its cover to flush it |

**Telegraph budget:** every attack gets ≥0.8s of readable wind-up (flash, arc
preview, or audio cue). No invisible hazards — carried directly from the v1.0
corrections brief.

### 2.3 Boss — "The Auditor Prime" (4 phases)
A three-storey mech suit piloted by the promoted ghost of Level 1's Auditor.
Arena: wide, two cover pillars that respawn between phases.

| Phase | HP band | Pattern | Player answer |
|---|---|---|---|
| **P1 — Assessment** | 100–75% | Walks the arena, fires slow tri-shot ledger bolts. Introduces the arena. | Basic cover discipline |
| **P2 — Audit Barrage** | 75–50% | Deploys 2 Tax Drones; bullet-hell curtain of audit papers with one safe lane that rotates. | Kill drones fast, read the lane |
| **P3 — Asset Seizure** | 50–25% | Vacuums cover pillars into itself as armor (removes your cover!) and charges. Weak spot: the intake vent, open 1.5s after each charge. | Punish the vent; survive coverless |
| **P4 — Final Notice** | 25–0% | Overheats itself: continuous beam sweep + falling debris. Cover respawns but breaks in 2 hits. | Bong Beam duel; keep moving |

**Token-holder spectacle (Movie Layer, cosmetic only, never difficulty):**
DIAMONDS holders see reflectable crystal shards in P2; GoldMine holders get a
golden emergency cover pillar in P4; SMOKE holders' overheat cooldown VFX is
gold-tinted. Non-holders fight the identical, fully fair fight.

---

## PAGE 3 — LEVELS, INTEGRATION, TECHNICAL PLAN

### 3.1 Level 4 — "Orbital Drop" (auto-scroller, ~3 min)
The drop-pod is on fire and falling. Forced downward scroll; Lil Blunt has
limited lateral movement across the pod's shattered hull.
- **Teaches:** aiming under pressure, Tier-1 ammo economy.
- **Beats:** open (empty sky, learn the aim) → incoming missiles (destroy or
  dodge) → debris field with Tax Drones → **checkpoint** → heat-shield failure
  (screen shake, faster scroll) → hull breach climax → ground impact.
- **No cover** by design: this level exists to make you *want* cover in L5.

### 3.2 Level 5 — "The Green Zone" (ground combat, ~6 min)
Occupied cannabis forest. The widest, most open level; verticality via a
**limited-fuel jetpack** (3s of thrust, refills on ground contact).
- **Teaches:** the cover system properly; Bandit Raider flanking.
- **Beats:** tutorial cover pocket → first Raider pair → jetpack canopy route
  (safer, fewer pickups) **vs.** ground route (riskier, more ammo) →
  **checkpoint** → Crystal Turret emplacement puzzle → extraction firefight.
- Route split honors the v1.0 three-route design language (Speedrun/Casual/
  Explorer) already proven in Levels 1–3.

### 3.3 Level 6 — "The Compliance Citadel" (indoor, ~7 min)
Tight corridors, heavy cover, ambush geometry. The claustrophobic climax.
- **Teaches:** peek-firing, Bong Beam heat management.
- **Beats:** breach → corridor turret gauntlet → server room (destructible
  everything) → **checkpoint** → elevator ambush (waves) → **Auditor Prime**.

### 3.4 Integration with v1.0 (must not break the platformer)
- **Unlock:** shooter mode appears on the menu only when
  `GameManager.highest_unlocked_level >= 3` **and** the campaign-complete flag
  is set. Uses the progression registry added in the v1.0 fix pass — no second
  source of truth.
- **Persistence:** `bong_tier`, `bong_ammo`, and `alien_seeds` live in
  `GameManager` alongside existing save data and serialize through the same
  `save_session()` path (one owner, per the state-ownership rules).
- **Cross-mode economy:** weed leaves (platformer) → ammo (shooter);
  **Alien Seeds** (shooter) → unlock platformer skins. Each mode makes the
  other more valuable; neither is required to enjoy the other.
- **Shared systems reused, not duplicated:** `AudioManager` (incl. the new
  music-override API for boss/Blaze transitions), `StateMachine`,
  `DifficultyManager` (invisible adaptive tuning applies to shooter deaths
  too), `Web3Bridge` analytics events, `ScreenShake`, `EffectSpawner`.
- **Offline:** every shooter feature works with zero backend, per project rule.

### 3.5 File plan (`src/shooter/`)
```
shooter_player.gd        # composes with existing player systems; adds weapon state
weapon_base.gd           # fire(), ammo cost, recoil, heat interface
weapon_bong_blaster.gd   # tier 1
weapon_spread.gd         # tier 2
weapon_homing.gd         # tier 3
weapon_beam.gd           # tier 4 + overheat
smoke_projectile.gd      # the shared bolt
cover_crate.gd           # HP, damage states, duck zone
enemy_shooter_base.gd    # patrol→alert→attack→reposition FSM + LOS raycast
enemy_drone.gd / enemy_turret.gd / enemy_raider.gd
boss_auditor_prime.gd    # 4 phases
level_04_orbital_drop.tscn / level_05_green_zone.tscn / level_06_compliance_citadel.tscn
prototype_room.tscn      # ← built first, this pass
```

### 3.6 Build order (prototype-first, per roadmap stop conditions)
1. **Prototype room** — Bong Blaster T1, one Tax Drone, two crates, cover duck.
   *Gate: does it feel like a shooter? If no, iterate before anything else.*
2. Enemy roster + Tier 2–3 weapons → Level 5 vertical slice (the fullest test).
3. Level 4 auto-scroller (simplest) → Level 6 → Tier 4 → Auditor Prime.
4. Integration + persistence + analytics, then ship gate (sentinel, audit,
   browser PLAYING verify) exactly as v1.0.

**Reference note:** `mshumer/Claude-of-Duty` is consulted for enemy-FSM and
LOS *architecture only* — no code copied (roadmap rule).

---

## Open questions for the founder
1. **Jetpack in L5** — does limited-fuel verticality fit Lil Blunt, or should
   it be a rideable smoke cloud (more on-brand, same function)?
2. **Ammo scarcity** — should the platformer's leaf count carry over fully, or
   cap per shooter level so v1.0 completionists aren't over-powered?
3. **Alien Seeds** — cosmetic skins only, or also a shooter-side upgrade
   currency? (Recommend cosmetic-only to keep the no-pay-to-win posture clean.)
