---
name: ep2-bow
description: Lil Blunt picks up the bears' bows and shoots back - FPS bow viewmodel, draw/hold/loose/swing animations, runner pickup drops, and 2D follow-through. TRIGGER on "bow", "bow and arrow", "pick up the bow", "archer", "bear bow", any edit to bear_archer hazards, gnome_arrow.gd, a new player projectile, Ep2ViewHands, or a second first-person weapon.
---
# Why (founder 2026-10-15)

"Lil Blunt shoots bears and some of them have bows and arrows so he can pick them up
and use them." The bears' side already exists: `bear_archer.glb` (Meshy, drawn-bow
Mine Bear Archer, `runner_view.gd:749`), runner `arrow` hazards with archer ids
(`episode2/runner/tracks/episode2_tracks.gd`), the bow-creak windup telegraph
(`runner_voice.gd:26`), and bear growl/death/attack VO (`runner_voice.gd:20-31`).
The 2D gnomes already shoot (`enemies/tax_collector.gd:126-197`,
`enemies/gnome_arrow.gd` — arrows must LOOK like arrows, never orbs). What does NOT
exist is Lil Blunt holding one. The Winchester (`ep2-fps-shooter-feel`,
`ep2_winchester.gd`) is the only first-person weapon and it is lesson-locked to
Inferno's teaching — the bow is Lil Blunt's TAKEN weapon, earned off a downed archer,
and it needs its own viewmodel, hands, and three motions: shooting, drawing, swinging.

Starter art (this session, Blender headless + Poly Haven softbox HDRI, same as the
train): `src/assets/models/player_bow/bow_fps_view.png` (1280x720 FPS-position
still: vertical recurve, nocked arrow, brass stud, red fletching) and
`player_bow_fps.blend`. Starter, not canon — re-frame via the VM placement sim
before shipping (rule 4).

# Rules

1. **The bow is taken, never given.** Runner: a shot archer falls procedurally
   (existing) AND drops a bow pickup on its ledge/rail; riding through it arms the
   bow. FPS chamber: the downed taxidermy bear's rack offers one. No bow appears in
   inventory, shops, or loadouts — if Lil Blunt did not take it off a bear, it is a
   bug. Pickup moment: bow rises into frame + arrow nocks + `bear_down` VO line.
2. **Three motions, all procedural, no textures** (repo rule — same as the gnome bow
   and arrow). String = two segments meeting at the nock; the nock lerps back with
   draw amount. Never a static bent texture.
   - **Draw/nock (0.45 s):** string 0→full, creak (`ep2_bow_creak`, already the
     telegraph sound — the player now makes the sound bears warn of), viewmodel
     drifts to center, FOV tightens one step. Nock only with quiver > 0.
   - **Hold:** tremble amplitude grows past 2.5 s, spread widens with it — no
     infinite full-draw aim. Loose on release (runner/FPS trigger) or auto-loose at
     4 s with max spread.
   - **Loose/shoot:** string snap + arrow spawn along the camera-aim cone (same hit
     test as the Winchester: gaussian cone from camera aim at fire time, pre-kick),
     view kick 0.8 deg recovering in ~0.12 s, twang + string-blur frame, quiver -1.
     Arrow in flight reuses the `gnome_arrow.gd` read: shaft + steel head + fletching,
     node rotated to velocity, NEVER an orb.
   - **Swing/melee (0.35 s, 0.9 s cooldown):** horizontal limb-bash arc for boarding
     bears and point-blank — consumes no arrow, interrupts draw, brief viewmodel roll.
   - **Idle:** breathing + walk bob + mouse lag layers identical to the rifle feel.
3. **Hands move this time.** `Ep2ViewHands.attach` hands are static capsules — fine
   for a rifle, wrong for a bow. Right leafy hand holds the grip; the LEFT hand must
   travel with the nock (draw/hold/loose). Rigid hand nodes re-posed per frame from
   draw amount, same no-skinned-arms rule as the Bull's props. Sights measured before
   hands attach; fingers stay capsules until a rigged-hand pass.
4. **Placement is simulated, not hand-placed.** Reuse `tools/ep2_sim/vm_placement_sim.mjs`
   with the bow mesh: vertical limbs are worse than a receiver for blocking the target
   window — target-window occupancy must be ~0% at rest AND at full draw (draw pulls
   the limbs wider). Ship the JSON next to the Winchester's (`docs/ep2_vm_placement_simulation.json`).
   Cant the bow ~10-15 deg like a real archer; a dead-vertical bow hides the lane.
5. **Canon lock.** Wood recurve limbs, leather grip, ONE brass stud (GoldMine trim),
   red fletching, steel bodkin head. Bear bows and Lil Blunt's bow share the pattern —
   his is recognizably THEIRS, taken. Balaclava-bear helmet/lamp motifs never transfer
   to the player.
6. **Numbers go through the sim.** Starters (change only via `fps_feel_sim.mjs`
   profiles + Jev, committed JSON): draw 0.45 s, quiver 6 + reserve 18, arrow speed
   55 m/s, damage 1 (runner bears fall when shot; chamber bear HP 2 = two arrows),
   spread sigma hip 1.8 deg / full-draw 0.5 deg / overhold up to 3.0 deg, swing arc
   100 deg / 1 dmg / 0.9 s cd. Never loose with quiver 0, never hold past 4 s, never
   fire during swing.

# 2D follow-through (Phase 2, same skill)

Gnome bows prove the side-view language (arc opening toward aim, nocked arrow appears
as cooldown ends — `tax_collector.gd:190-197`). Player bow pickup in 2D: tall vertical
art anchors like a POLE (torch/pickaxe math in `lil_blunt_visual.gd`, NOT the sidearm
math), fires `gnome_arrow`-pattern projectiles via `combat_handler.gd` behind a
`_uses_bow()` gate next to `_uses_revolver()`. Melee swing reuses the swing arc.

# Gate (every time)

- New test scene + sim JSON committed (mirror `ep2_range_lesson_test.tscn` stages):
  pickup, draw, full-draw hold, loose, quiver-empty click, swing interrupt, overhold
  auto-loose.
- Real-render captures: hip, full draw (string visibly back, arrow on rest), loose
  frame, swing mid-arc, pickup rise — target window clear in ALL of them, looked at
  by a human, not just metered.
- Bear loop closed live: shoot archer → falls + drops bow → ride through → armed →
  `bear_down` VO fires; quiver HUD ticks down per shot.
- Live proof before "done" (`browser-verify-game`).
