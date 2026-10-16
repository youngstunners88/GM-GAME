# Still Water - lake WIRE SPEC (layer 2)            status: draft for founder review (reviewed 2026-10-16, 3 fixes below)
Region canon: `design/world/regions/11_still-water-lake.md`. Protocol canon: `design/goldmine_protocol_design.md`
Pillars 1-2 only (Phase 1). Workflow: `ep2-layered-production` layer 2. Layer 1 (founder target image) is still
missing, so no beat has a reference image yet. The layer-1 gate stays open until it does.
FREEZE: no Pillar 5 / certificates / SWF. No CONFIDENTIAL items. No addresses. No invented tokenomics.

## 1. Purpose + player fantasy
Still Water is a CALM beat between the bar draw and the Fort Knox approach. It has no enemies, no damage and no fail state.
The player is a small, chill Lil Blunt on a quiet dock. The water rises while he waits, fishes and watches the
GoldMine train hurry along the far horizon. The lake turns Pillar 1 and Pillar 2 into a place. Waiting fills the pole,
grabbing early spills water, one shard in five sinks for good, and the far basin only fills for those who stay.
He leaves understanding why the Bull never hurries. He does not leave with a new weapon.

## 2. Verbs (the only ones live in this region)
- **walk**: move along the goat track, shoreline and dock. There is no run, jump or shoot.
- **look**: hold to drift the view toward a point of interest (pole, train, basins, lakebed, horse).
- **sit**: sit on the dock edge. It is cosmetic and changes no timer.
- **fish/wait**: cast a line from the dock and idle. The bobber is cosmetic. Nothing is caught and nothing is scored.
- **scoop**: dip the bucket at the pole. Single use. The bucket keeps the vested part and the unvested part spills.
- **open sluice**: turn the wheel between the two basins. It can be used any time. It releases whatever has filled so far.
- **drop shard**: tip the handful of diamond shards from the unfinished boat into the lake. Single use, one handful.

## 3. Beats
All timing runs on one lake clock **T** (seconds of play inside lake bounds). T starts at 0 when the player crosses
the shoreline trigger. It stops while the game is paused. Nothing is frame-counted.

1. **Arrival by goat track**
   - Trigger: the player leaves the town back lane onto the goat track. Walking is continuous, with no loading black (`ep2-no-blackouts`).
   - On screen: the ridge lip reveals the bowl valley. Dawn mist lies on black water. The dock is centred, with the unlit lantern on it.
   - Length: walk of about 8 s down the track (`TRACK_WALK_S`). The lake clock is not running yet.
   - Player may: walk, look.
2. **First sight of the far train**
   - Trigger: T = `TRAIN_FIRST_PASS_T`.
   - On screen: a small black and brass silhouette enters the far rail line from the left. Its plume crawls behind it and is mirrored in the water. A faint whistle plays. The heron lifts off and resettles.
   - Length: one transit, `TRAIN_TRANSIT_S`.
   - Player may: everything. Look snaps the drift target to the train once, and only if the player is already looking.
3. **The vesting pole filling**
   - Trigger: T = 0 (shoreline crossed).
   - On screen: the waterline on the pole climbs one notch every `DAY_S`. A gold lantern-light glints at the waterline. No timer, number or bar is shown.
   - Length: `NOTCHES * DAY_S` = 100 s to full.
   - Player may: walk, look, sit, fish/wait, scoop.
4. **Early-scoop choice + visible cost**
   - Trigger: the player uses scoop at the pole, at notch n (n = floor(T / DAY_S), clamped to 0-100).
   - On screen: the bucket comes up holding n/100 of its height and is poured into the clay jar on the dock. The unvested part, from notch n to 100, shows as a pale band on the pole. That band spills out as a ripple ring, runs to the old dam outlet and is gone.
     - The pole then stops rising. Its empty notches stay visible for the rest of the visit, and so does the jar level.
     - At n = 100 the jar fills completely and nothing spills.
   - Length: dip + pour `SCOOP_ANIM_S`, then spill ring `SPILL_RING_S`.
   - Player may: continue everything else. Scoop is spent.
   - If the player never scoops, nothing is lost. The pole simply stands full.
5. **Diamond shards (permanent sink)**
   - Trigger: drop shard at the boat. Available from T = 0.
   - On screen: `SHARD_COUNT` shards fall in. Exactly one sinks, slowly, and becomes a glow on the lakebed that stays for the visit. The others bob back to the dock edge as glints.
   - Length: `SHARD_SINK_S`.
   - Player may: everything. Drop shard is spent.
6. **Two-basin sluice**
   - Trigger: basins fill on T from 0.
   - Near basin (60 share): full at `NEAR_FULL_T`.
   - Far basin (40 share): full at `FAR_FULL_T`.
   - On screen: water creeps up both basin walls.
     - Opening the sluice releases whatever has filled so far into a single glow across the sluice lip.
     - Opening after `NEAR_FULL_T` releases the near share in full.
     - Opening at or after `FAR_FULL_T` releases both shares in full.
     - Opening early still releases something. It is never zero once T > 0, and it never causes damage.
   - Length: wheel turn `SLUICE_ANIM_S`. Release flow `SLUICE_FLOW_S`.
   - Player may: everything. Open sluice is single use.
7. **The horse arrives**
   - Trigger: T = `HORSE_ARRIVE_T`.
   - On screen: a ranch horse walks out of the willows, along the shore and to the dock end. It drinks and then stands. If Lil Blunt is sitting, the horse lowers its head beside him.
   - Length: walk-in `HORSE_WALK_S`. It then stays until the player leaves.
   - Player may: everything. There is no interaction gate. Sitting next to it is the calm beat.
8. **Full sun-arc / lantern**
   - Trigger: T = `SUN_ARC_S`, with the player still in lake bounds.
   - On screen: golden hour. The lantern on the dock lights, and nobody is seen lighting it. The far basin glows at full intensity (`MAX_TERM_BONUS`). Frogs and night insects come in. The ridge path toward Fort Knox opens.
   - Length: lantern fade-in `LANTERN_FADE_S`. The lake then idles forever.
   - Player may: everything, plus leave by the ridge path.
   - Reward: one cosmetic only. It grants no stat and no item, and makes no economy write.

**Leaving**
- The town track is open at every T. Taking it ends the visit with no penalty, and the lantern stays unlit.
- Lake state is not saved. Re-entry restarts at T = 0.

## 4. Numbers table (DATA-DRIVEN)
**Compression ratio:** 1 protocol day = `DAY_S` = 1.0 s of play, i.e. 86 400 : 1.

**Sun-arc length:** the sun-arc is mapped to the 288-day minimum Fort Knox commitment. So the pole (100 days) fills
first, the near basin (day 88) fills inside that, and the far basin (day 288) lands exactly at the end of the arc.

**Value classes**
- **P** = derived from protocol constants.
- **F** = feel value, free to tune. It must not be read as protocol.

| name | value | unit | note |
|---|---|---|---|
| DAY_S | 1.0 | s | P-ratio: one vesting/staking day of play; scales every P time below |
| NOTCHES | 100 | notches | P: MINER_VESTING_DAYS = 100 |
| NOTCH_RATE | 0.01 | fraction/day | P: 1%/day linear |
| POLE_FULL_T | 100 | s | P: NOTCHES * DAY_S |
| SPILL_FRACTION(n) | (100 - n) / 100 | fraction | P: early claim forfeits unvested; n = notch at scoop |
| KEPT_FRACTION(n) | n / 100 | fraction | P: 1 - SPILL_FRACTION(n) |
| SHARD_COUNT | 5 | shards | P: per protocol doc game translation (5 raw, 1 burned) |
| SUNK_FRACTION | 0.20 | fraction | P: DIAMOND_BURN_PCT |
| SHARDS_SUNK | 1 | shards | P: SHARD_COUNT * SUNK_FRACTION |
| NEAR_SHARE | 0.60 | fraction | P: FORT_KNOX_SHORT_POOL_PCT |
| FAR_SHARE | 0.40 | fraction | P: FORT_KNOX_LONG_POOL_PCT |
| NEAR_FULL_T | 88 | s | P: short pool day 88 * DAY_S |
| FAR_FULL_T | 288 | s | P: long pool day 288 * DAY_S |
| SUN_ARC_S | 288 | s | P: = FAR_FULL_T (4.8 min) |
| MAX_TERM_BONUS | 1.00 | glow multiplier | P: MAX_TERM_BONUS_PCT, far-basin glow intensity at SUN_ARC_S |
| SUN_START_DEG | 8 | deg elevation | F: dawn, east |
| SUN_END_DEG | 172 | deg along arc | F: golden hour, west, low |
| MIST_CLEAR_T | 60 | s | F: mist alpha 1 -> 0.2 |
| TRAIN_FIRST_PASS_T | 12 | s | F |
| TRAIN_PERIOD_S | 96 | s | F: whistle period, passes at T = 12, 108, 204 |
| TRAIN_TRANSIT_S | 40 | s | F: left-to-right across the far layer |
| TRAIN_SPEED | 32 | px/s | F: 1280 px / TRAIN_TRANSIT_S |
| WHISTLE_DELAY_S | 1.5 | s | F: whistle sounds after the first plume puff (distance) |
| WHISTLE_GAIN_DB | -18 | dB | F: far, never startling |
| SCOOP_ANIM_S | 2.0 | s | F |
| SPILL_RING_S | 3.0 | s | F: ripple ring to dam outlet |
| SHARD_SINK_S | 4.0 | s | F |
| SLUICE_ANIM_S | 2.0 | s | F |
| SLUICE_FLOW_S | 3.0 | s | F |
| HORSE_ARRIVE_T | 144 | s | F: half arc |
| HORSE_WALK_S | 12 | s | F. The walk-in is 640 px. The stable horse's walk cycle has a 92 px stride (`src/assets/models/horse/assetfurnace/rig_report.json`), so at 12 s run the walk animation at 10 fps * (640 / 12) / 76.5 = 6.97 fps, or the hooves skate |
| LANTERN_FADE_S | 3.0 | s | F |
| TRACK_WALK_S | 8 | s | F: ridge lip to shoreline trigger |
| WALK_SPEED | 120 | px/s | F: no run in this region |
| REFLECTION_ALPHA | 0.35 | 0-1 | F: sky/train mirror strength |

**Sluice release at T**
- Formula: `released = NEAR_SHARE * min(T / NEAR_FULL_T, 1) + FAR_SHARE * min(T / FAR_FULL_T, 1)`.
- The maximum is 1.0. Both fills are linear, which matches the linear vesting shape.

## 5. Layout
- **Reference frame:** 1280x720. World units equal reference px.
- **3D passes:** any 3D pass maps 100 px = 1 m.
- **Depth layers, back to front:** sky, far ridge + rail, water, mid (dock/pole/basins/boat), foreground shore.
- **Camera:** the layout holds whether the camera is side view or first person facing the rail.

| element | x (px) | y (px) | size (px) | note |
|---|---|---|---|---|
| sky | 0-1280 | 0-290 | - | sun-arc travels here |
| far ridge | 0-1280 | 250-300 | - | low, open side of the bowl |
| far rail line | 0-1280 | 296 | 1 px line | train rides on it |
| train silhouette | moves | 270-296 | ~64 x 26 | far layer only |
| waterline (mirror axis) | 0-1280 | 340 | - | reflections flip about y=340 |
| water | 0-1280 | 340-600 | - | still, planar mirror |
| dam outlet | 1240-1280 | 340-380 | - | spill ring exits here |
| unfinished boat | 340-440 | 560-600 | 100 x 40 | shard handful sits here |
| heron | 230-260 | 520-580 | 30 x 60 | reeds left |
| dock | 520-760 | 560-600 | 240 x 40 | centre, lantern at x=740 |
| vesting pole | 700 | 380-580 | 8 x 200 | 100 notches, 2 px apart, unnumbered |
| clay jar | 600 | 540-560 | 20 x 20 | holds KEPT_FRACTION |
| lakebed glow | 640 | 590 | 24 r | sunk shard, stays |
| near basin | 880-1040 | 500-600 | 160 x 100 | 60 share |
| sluice wheel | 1060 | 520-580 | 20 x 60 | between basins |
| far basin | 1080-1240 | 500-600 | 160 x 100 | 40 share |
| shoreline (walkable) | 0-1280 | 600-720 | - | foreground reeds/willows |
| goat-track entry/exit | 0-80 | 600-720 | - | to town back lane |
| ridge path exit | 1200-1280 | 600-660 | - | to Fort Knox, opens at SUN_ARC_S |
| horse spawn | 120 | 610 | - | willows, walks to x=760 |

```text
y   0 +--------------------------------------------------------------+
      |                         sky  (sun-arc ->)                     |
  250 |~~~~~~~~~~~~~~~~~~~~~~~~ far ridge ~~~~~~~~~~~~~~~~~~~~~~~~~~~~|
  296 |====[train]~~plume====================================rail=====|
  340 |------------------------ waterline / mirror ------------------|dam
      |                     [train reflection]                       |out
      |                           |pole                              |
      |                           |                                  |
  500 |                           |              [near ]  @ [ far  ] |
  560 |   heron    [boat]   [jar][==dock==*]     [basin]  @ [basin ] |
  590 |                       o lakebed glow                         |
  600 |~~~~~~~~~~~~~~~~~~~~~~~~ shoreline ~~~~~~~~~~~~~~~~~~~~~~~~~~~|
      |track> horse                                         <ridge  |
  720 +--------------------------------------------------------------+
      x 0                    640                                1280
   * lantern   @ sluice wheel   | vesting pole   o sunk shard glow
```

## 6. The train
- **Must exist (founder lock).**
- **Look:** black + brass 4-4-0 with the GM medallion. It is always tiny on the far rail line at y=296. It never leaves the far layer, never comes nearer and cannot be boarded. There is no interaction prompt.
- **Asset:** `src/assets/models/goldmine_train/sprite_prop_train-goldmine_512.png`, scaled to about 64 px wide in the far layer. The glb in the same folder is NOT used here, because there is no nearer pass at the lake.
- **Plume:**
  - Soft grey puffs drawn by the view, trailing the stack and drifting straight up (there is no wind).
  - Puffs fade over about 6 s.
  - The view needs no extra texture asset for this.
- **Whistle:**
  - Every `TRAIN_PERIOD_S` from `TRAIN_FIRST_PASS_T`, played `WHISTLE_DELAY_S` after the first puff of each pass.
  - Far, low gain. The SFX is still to be made (whistle SFX, train far, listed in region Assets).
- **Reflection:**
  - The silhouette and plume are mirrored about y=340 at `REFLECTION_ALPHA`, with gentle vertical ripple distortion.
  - The plume reflection is the part players should notice.
- **Meaning:** it is the hurried world's clock. The schedule is the only fast thing in the frame, and it never waits for the player.

## 7. Metaphor contract
**The lake teaches the SHAPE only:**
- Time rewards (the pole fills linearly).
- Impatience costs exactly the unvested part (spill).
- One fifth of the shards is a permanent sink.
- Rewards come in two waves, 60 then 40, and the second only comes to those who stay.
- Staying the full term is honoured. That honour is a lantern, not a number.

**The lake must NEVER show:**
- token balances, prices, yield/APY, percentages, day counts, timers or progress bars
- digits on the pole (notches are bare marks), in any prompt, or in dialogue
- token names or tickers in player text at the lake
- HUD economy toasts while the player is in lake bounds
- wallet or contract addresses, real or fake
- Pillar 5 certificates, SWF tiers, Phase 2 anything, or anything marked CONFIDENTIAL
- enemies, damage, weapons drawn, aggressive weed jokes, the Wild, or the Bull (he is absent here)

**Economy side effects:** the lake writes nothing to `GoldMineSystem`. Scoop, shards and sluice are cosmetic sim state only.

**Tone:**
- Lil Blunt stays small, chill and friendly. Idle lines are short and kind ("water's not ready yet. that's fine.").
- Text is lowercase, with no digits.

## 8. Solvability / acceptance gate
A headless sim test (the test name is set by the implementer) must assert all of the following.

**Completion and no fail state**
- [ ] **No inputs:** with zero player input after the shoreline trigger, T reaches `SUN_ARC_S`. The lantern lights, the ridge path opens and the visit can end. No fail or death flag exists in lake state.
- [ ] **Town exit:** leaving by the town track is accepted at every sampled T in [0, SUN_ARC_S + 10] at 1 s steps, and every exit ends the visit cleanly.
- [ ] **Ridge exit:** leaving by the ridge path is accepted for T >= `SUN_ARC_S` and refused before it, with a gentle prompt and no penalty.
- [ ] **Verb combinations:** for every combination of {scoop at n in 0..100 or never} x {drop shard yes/no} x {sluice at T in {1, 44, 88, 200, 288} or never} x {sit yes/no}, the run reaches an end state.
- [ ] **No damage:** player health is unchanged throughout. No damage source exists in the region.

**Scoop**
- [ ] For every n in 0..100: `spilled == (100 - n) / 100` and `kept == n / 100` (abs error <= 1e-6), and `kept + spilled == 1`.
- [ ] A second scoop is rejected.
- [ ] After a scoop, the pole level never increases.

**Shards**
- [ ] After drop shard: `sunk == 1`, `recovered == 4`, and `sunk / SHARD_COUNT == DIAMOND_BURN_PCT`.
- [ ] The sunk glow persists until the visit ends.
- [ ] A second drop is rejected.

**Pole and basins**
- [ ] With no scoop, the pole is at notch 100 exactly at T = 100. (After a scoop it stops by design; assert it never rises instead.)
- [ ] The near basin is full exactly at T = 88. The far basin is full exactly at T = 288.
- [ ] `NEAR_SHARE + FAR_SHARE == 1`.
- [ ] `released(T)` matches the formula in section 4. It is 1.0 for T >= 288.

**Determinism**
- [ ] Sun angle, pole level, basin levels and train x are pure functions of T.
- [ ] Stepping the sim at 1/30 s and 1/60 s gives identical values at T = 50, 100, 200 and 288 (abs error <= 1e-4).

**Train**
- [ ] Train pass start times within the arc are exactly [12, 108, 204].
- [ ] Train y never differs from the far rail line. Its scale never exceeds the far-layer cap. No board/interact action exists.

**Lantern**
- [ ] Lit iff T >= `SUN_ARC_S` and the player never left during this visit.
- [ ] The far basin glow equals `MAX_TERM_BONUS` at that moment.

**Text and economy**
- [ ] No lake player string contains a digit, `%`, a currency sign, `0x`, or a token name or ticker.
- [ ] No lake code path calls into `GoldMineSystem`.

## 9. Open questions for the founder
1. **Compression:** A) 1 day = 1 s, sun-arc 4.8 min, or B) 1 day = 2 s, sun-arc 9.6 min?
2. **Sitting speed:** should sitting with the horse run the lake clock 2x? (yes/no). The current spec says no, and every verb runs at 1x.
3. **After an early scoop:** A) the pole stops rising (claim closes the position, as spec'd), or B) the pole keeps rising as a "what you would have had" ghost?
4. **Ridge exit:** keep the ridge path to Fort Knox gated on the full sun-arc? (yes/no). The town track always stays open.
5. **Who sends Lil Blunt to the lake:** A) Sheriff Jake's witness line after the draw, or B) the horse, which leads him there?
6. **Camera:** the repo locks Episode 2 to first person (no third-person follow camera), but section 5 is laid out as a 2D 1280x720 frame. Confirm first person here, in which case section 5 is the layout for the layer-3 3D pass (100 px = 1 m) and the far train/horse are cards or models in that scene.

NOTES: Layer-1 gate is still open, so a founder target image is needed per beat before layer 3. The far whistle SFX is listed as needed but not yet made.
