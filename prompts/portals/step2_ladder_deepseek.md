You are drafting code for a Godot 4.3 GDScript 2D platformer (non-threaded HTML5 export, GL Compatibility renderer, viewport 1280x720, stretch canvas_items). Output ONLY files, each wrapped exactly like:
=== FILE: <res-relative path> ===
<contents>
=== END ===
For the three stage .tscn files output the COMPLETE new file content (not a diff). No prose outside the blocks.

TASK — Protocol Portals build step 2: a glowing DOWNWARD portal ladder on the boss-approach path of Stages 1-3.

Deliver:
1. src/protocol_portals/PortalLadder.gd (`extends Node2D`, `class_name PortalLadder`) + src/protocol_portals/PortalLadder.tscn (root Node2D with this script; build all visuals in code so the .tscn is minimal).
   - @export var protocol: String = "smoke"   # "smoke" | "diamonds" | "gold"
   - @export var stage_id: int = 1
   - Glow colour by protocol: smoke neon green Color(0.35,1.0,0.45), diamonds cyan Color(0.35,0.95,1.0), gold lantern Color(1.0,0.78,0.25).
   - Visual: a ladder going DOWN into the ground (a shaft opening at floor level: dark hole ~64 px wide drawn slightly below floor, two rails + rungs descending ~120 px into it), a pulsing additive glow halo (Sprite2D or Polygon2D/ColorRect with CanvasItemMaterial blend_mode ADD) ~160x200 px, pulsing 0.55..1.0 alpha at ~1.4 Hz via _process + sin (no Tween loops left running when freed), a PointLight2D is NOT allowed (compatibility renderer cost) — use additive sprites only. Plus a small floating Label above it: "▼ STUDY" in the glow colour, font size 18, with a dark outline (outline_size 6), visible always so it is readable at gameplay zoom. Use z_index 5 so it draws over background and ground tiles.
   - Rising glow particles: CPUParticles2D (NOT GPUParticles2D), ~18 amount, small squares, upward, glow colour, local_coords false.
   - Area2D "EnterZone" (collision_layer 0, collision_mask 2 — the player is on layer 2; ALSO check body.is_in_group("player")), RectangleShape2D ~64x80 centred on the shaft mouth. While the player is inside, show the prompt text "▼ STUDY  [E]"; when the player presses the "interact" action inside the zone emit `signal portal_requested(protocol: String, stage_id: int)` and print one line. Do NOT change scenes, do NOT warp, do NOT create a PortalSession (the study room does not exist yet — step 3 wires it).
   - FLOOR SNAP: the level ground is built at runtime by the parent level (extends LevelBase), which has `func _floor_y_at(x: float) -> float`. Child _ready runs BEFORE the parent builds ground, so in _ready do `call_deferred("_snap_to_floor")`; _snap_to_floor walks up get_parent() chain to find a node with has_method("_floor_y_at") and sets global_position.y to that floor y. If none found, keep the authored position.
   - Must NOT block the player: no StaticBody2D / no solid collision at all.
   - Static typing, 4-space indentation, well commented. No Thread, no OS.execute, no Expression, no JavaScriptBridge, no network.
   - Add `add_to_group("protocol_portal")`.

2. The three stage scenes, each with ONE new PortalLadder instance added as a child of the root (add ext_resource for res://src/protocol_portals/PortalLadder.tscn with a new unique id and bump load_steps by 1; keep EVERYTHING else byte-identical, including uids):
   - src/level/level_01_smoke_realm.tscn  → name "PortalLadderSmoke", protocol "smoke", stage_id 1
   - src/level/level_02_crystal_caverns.tscn → name "PortalLadderDiamonds", protocol "diamonds", stage_id 2
   - src/level/level_03_gold_rush.tscn  → name "PortalLadderGold", protocol "gold", stage_id 3
   Placement rules (founder spec): on the boss-approach path, readable BEFORE the fight, NOT inside the boss trigger/hitbox, and NOT on or next to the Blaze Portal, Smoke Lounge door, Hall of Blaze, Diamond Vault door, Gold Rush Reserve or Fort Knox entries (keep >= 200 px horizontal clearance from each of those; read their x positions in the level .gd files below). Aim ~250-450 px left of the boss trigger's x. Set position y = 500 (floor snap corrects it). State in a GDScript comment line inside each .tscn? No — .tscn has no comments; instead put the chosen x and reasoning for each stage as comments at the top of PortalLadder.gd.

3. tests/portal_ladder_test.gd (`extends SceneTree`, run with godot --headless --script): for each of the three stage scenes: load + instantiate, add to root, await two process frames, find exactly one node in group "protocol_portal", assert its protocol/stage_id, assert its global x is less than the BossTrigger's CollisionShape2D global x, assert it has no StaticBody2D descendants, assert it has an Area2D named EnterZone. Print "[PASS]/[FAIL] ..." and finally "PORTAL LADDERS: ALL PASS" or "PORTAL LADDERS: FAILURES n", quit(0/1). preload scripts by path, do not rely on class_name globals.

NEGATIVE EXAMPLE — the existing climb ladder below is a DIFFERENT feature. Do NOT reuse, extend, instance or modify it, and do not copy its climb behaviour:
@include src/level/ladder.gd

STAGE SCENES (edit these):
@include src/level/level_01_smoke_realm.tscn
@include src/level/level_02_crystal_caverns.tscn
@include src/level/level_03_gold_rush.tscn

STAGE SCRIPTS (read-only; use them for door/portal x positions):
@include src/level/level_01_smoke_realm.gd
@include src/level/level_02_crystal_caverns.gd
@include src/level/level_03_gold_rush.gd
